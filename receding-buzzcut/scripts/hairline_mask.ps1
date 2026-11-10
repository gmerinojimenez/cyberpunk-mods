# Generates the receding-hairline cap mask from the vanilla buzzcut mask.
# Texture space: 1024 px, top = forehead, ~100 px ~= 3 cm of scalp. White = hair.
param(
  [Parameter(Mandatory)][string]$In,       # vanilla hh_999_ma__cap_mask.png
  [Parameter(Mandatory)][string]$Out,      # edited mask (png)
  [string]$Preview,                        # optional: original | edited, hairline drawn in red
  [double]$CenterLine   = 70,    # Y of the centre of the hairline (vanilla edge ~55)
  [double]$TempleLine   = 200,   # Y of the deepest point of each temple recession (vanilla ~170)
  [double]$TempleX      = 210,   # horizontal distance from the centre to each recession
  [double]$VPower       = 1.15,  # only when Roundness < 1: 1 = straight V, >1 = rounder tip
  [double]$Roundness    = 1.0,   # 0 = straight-line V (pointy), 1 = smooth curve without corners
  [double]$SideFalloff  = 110,   # how fast the line comes forward again past the recession
  [double]$EdgeSoft     = 18,    # softness of the hairline edge
  [double]$TopDensity   = 0.5,   # density of the top relative to the sides (1 = same, 0 = bald)
  [double]$TopWidth     = 200,   # width of the thinned top area
  [double]$TopEndY      = 520,   # how far back (towards the nape) the top thinning reaches
  [double]$FrontDensity = 0.85,  # extra thinning right behind the hairline
  [double]$FrontBand    = 70,    # width of that band
  [double]$CrownThin    = 0.10,  # extra thinning at the crown whorl
  [double]$Grain        = 3,     # size of the thinning grain (px); bigger survives mipmaps/distance
  [int]$Seed            = 1977
)
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @"
using System;
using System.Drawing;
using System.Drawing.Imaging;

public static class HairlineMask {
  static double Smooth(double a, double b, double x){ double t=Math.Max(0,Math.Min(1,(x-a)/(b-a))); return t*t*(3-2*t); }
  static double Hash(int x, int y, int s){ unchecked { uint h=(uint)(x*374761393 + y*668265263 + s*1442695041); h=(h^(h>>13))*1274126177u; h^=h>>16; return (h & 0xFFFFFF)/16777216.0; } }
  static double VNoise(double x, double y, int s){
    int xi=(int)Math.Floor(x), yi=(int)Math.Floor(y); double fx=x-xi, fy=y-yi;
    fx=fx*fx*(3-2*fx); fy=fy*fy*(3-2*fy);
    double a=Hash(xi,yi,s), b=Hash(xi+1,yi,s), c=Hash(xi,yi+1,s), d=Hash(xi+1,yi+1,s);
    return a+(b-a)*fx+(c-a)*fy+(a-b-c+d)*fx*fy;
  }
  public static double Roundness = 1.0;
  public static double HairLine(double X, double center, double temple, double tx, double vp, double fall, int seed){
    double d = Math.Abs(X-512);
    double t = Math.Min(d/tx, 1.0);
    // straight V (t^vp) blended with a corner-free curve (smootherstep: zero slope at the centre and at the recession)
    double sV = Math.Pow(t, vp);
    double sR = t*t*t*(t*(t*6-15)+10);
    double s = sV + (sR - sV)*Roundness;
    double y = center + (temple-center)*s;
    if (d > tx) { double e=(d-tx)/fall; y = center + (temple-center)*Math.Exp(-e*e) ; if (y < center) y = center; }
    y += (VNoise(X/24.0, 0.5, seed)-0.5)*10 + (VNoise(X/5.0, 3.5, seed+1)-0.5)*6;
    return y;
  }
  public static void Run(string inp, string outp, string prev, double center, double temple, double tx, double vp, double fall,
                         double edge, double topD, double topW, double topEnd, double frontD, double frontBand,
                         double crown, double grain, int seed) {
    var src = new Bitmap(inp);
    int W=src.Width, H=src.Height; double k = W/1024.0;
    var dst = new Bitmap(W,H,PixelFormat.Format32bppArgb);
    var pv  = new Bitmap(W*2,H,PixelFormat.Format24bppRgb);
    for (int y=0;y<H;y++) for (int x=0;x<W;x++) {
      double v = src.GetPixel(x,y).R/255.0;
      double X=x/k, Y=y/k;
      double hl = HairLine(X, center, temple, tx, vp, fall, seed);
      double line = Smooth(hl-edge*0.5, hl+edge, Y);
      // top thinner than the sides
      double wx = Math.Exp(-Math.Pow((X-512)/topW,2));
      double wy = 1 - Smooth(topEnd-140, topEnd, Y);
      double dens = 1 - wx*wy*(1-topD);
      // band right behind the hairline
      dens *= frontD + (1-frontD)*Smooth(hl, hl+frontBand, Y);
      // crown whorl
      double dc = (Math.Pow(X-550,2)+Math.Pow(Y-470,2))/(95.0*95.0);
      dens *= 1 - crown*Math.Exp(-dc);
      // drop hairs in coarse clumps so the thinning survives mipmaps
      double n = 0.75*VNoise(X/grain, Y/grain, seed+7) + 0.25*VNoise(X/(grain*0.4), Y/(grain*0.4), seed+9);
      double keep = Smooth(-0.06, 0.06, dens - n);
      double o = v*line*keep;
      int g=(int)Math.Round(Math.Max(0,Math.Min(1,o))*255);
      dst.SetPixel(x,y,Color.FromArgb(255,g,g,g));
      int g0=(int)Math.Round(v*255);
      pv.SetPixel(x,y,Color.FromArgb(g0,g0,g0));
      if (Math.Abs(Y-hl) < 1.0) pv.SetPixel(x+W,y,Color.FromArgb(255,40,40)); else pv.SetPixel(x+W,y,Color.FromArgb(g,g,g));
    }
    dst.Save(outp, ImageFormat.Png);
    if (!string.IsNullOrEmpty(prev)) pv.Save(prev, ImageFormat.Png);
    src.Dispose(); dst.Dispose(); pv.Dispose();
  }
}
"@
[HairlineMask]::Roundness = $Roundness
[HairlineMask]::Run($In, $Out, $Preview, $CenterLine, $TempleLine, $TempleX, $VPower, $SideFalloff, $EdgeSoft,
               $TopDensity, $TopWidth, $TopEndY, $FrontDensity, $FrontBand, $CrownThin, $Grain, $Seed)
"Mask written: $Out"

