import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Deterministic extraction from the Tuko master. Coordinates are in its original
// 1254px, top-left coordinate system; no independently generated part is used.
// Usage: swift build_tuko_master_rig.swift art/tuko
let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "art/tuko")
let fm = FileManager.default
struct Raster {
  var w: Int; var h: Int; var p: [UInt8]
  init(_ url: URL) {
    let s = CGImageSourceCreateWithURL(url as CFURL, nil)!
    let im = CGImageSourceCreateImageAtIndex(s, 0, nil)!
    w = im.width; h = im.height
    p = [UInt8](repeating: 0, count: w*h*4)
    let width = w, height = h
    p.withUnsafeMutableBytes { raw in
      let c = CGContext(data: raw.baseAddress, width: width, height: height,
        bitsPerComponent: 8, bytesPerRow: width*4, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
      c.draw(im, in: CGRect(x: 0, y: 0, width: width, height: height))
    }
  }
  init(_ w: Int, _ h: Int) { self.w=w; self.h=h; p=[UInt8](repeating:0,count:w*h*4) }
  func image() -> CGImage {
    CGImage(width:w,height:h,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:w*4,
      space:CGColorSpaceCreateDeviceRGB(),
      bitmapInfo:CGBitmapInfo(rawValue:CGImageAlphaInfo.premultipliedLast.rawValue),
      provider:CGDataProvider(data:Data(p) as CFData)!,decode:nil,shouldInterpolate:true,intent:.defaultIntent)!
  }
  func save(_ path: String, magenta: Bool = false) throws {
    let url = root.appendingPathComponent(path)
    try fm.createDirectory(at:url.deletingLastPathComponent(),withIntermediateDirectories:true)
    var r = self
    if magenta {
      for i in stride(from:0,to:p.count,by:4) {
        let a = Int(p[i+3])
        r.p[i] = UInt8(min(255,Int(p[i])+255-a))
        r.p[i+1] = p[i+1]
        r.p[i+2] = UInt8(min(255,Int(p[i+2])+255-a))
        r.p[i+3] = 255
      }
    }
    let out=CGImageDestinationCreateWithURL(url as CFURL,UTType.png.identifier as CFString,1,nil)!
    CGImageDestinationAddImage(out,r.image(),nil)
    precondition(CGImageDestinationFinalize(out))
  }
  func keyed() -> Raster {
    var r=self
    for i in stride(from:0,to:p.count,by:4) {
      let red=Int(p[i]), green=Int(p[i+1]), blue=Int(p[i+2])
      if red > 165 && blue > 140 && green < 120 && blue-green > 90 {
        for c in 0..<4 { r.p[i+c]=0 }
      }
    }
    return r
  }
  func largestComponent() -> Raster {
    var seen=[Bool](repeating:false,count:w*h), best:[Int]=[]
    for seed in 0..<w*h where !seen[seed] && p[seed*4+3]>0 {
      var q=[seed], k=0;seen[seed]=true
      while k<q.count {
        let j=q[k];k+=1;let x=j%w,y=j/w
        for (dx,dy) in [(-1,0),(1,0),(0,-1),(0,1)] {
          let nx=x+dx,ny=y+dy
          if nx>=0 && nx<w && ny>=0 && ny<h {
            let n=ny*w+nx
            if !seen[n] && p[n*4+3]>0 {seen[n]=true;q.append(n)}
          }
        }
      }
      if q.count>best.count {best=q}
    }
    var r=Raster(w,h)
    for j in best {let i=j*4;r.p[i..<i+4]=p[i..<i+4]};return r
  }
  func filledHoles() -> Raster {
    var outside=[Bool](repeating:false,count:w*h),q:[Int]=[]
    for x in 0..<w {q.append(x);q.append((h-1)*w+x)}
    for y in 0..<h {q.append(y*w);q.append(y*w+w-1)}
    for j in q {outside[j]=true};var k=0
    while k<q.count {
      let j=q[k];k+=1;let x=j%w,y=j/w
      for (dx,dy) in [(-1,0),(1,0),(0,-1),(0,1)] {
        let nx=x+dx,ny=y+dy
        if nx>=0 && nx<w && ny>=0 && ny<h {
          let n=ny*w+nx
          if !outside[n] && p[n*4+3]==0 {outside[n]=true;q.append(n)}
        }
      }
    }
    var r=self
    for j in 0..<w*h where !outside[j] && p[j*4+3]==0 {
      let i=j*4;r.p[i..<i+4]=master.p[i..<i+4]
    };return r
  }
  func masked(_ path:CGPath, test:((Int,Int,Int)->Bool)? = nil) -> Raster {
    let a=coverage(path,w,h)
    var r=self
    for j in 0..<w*h {
      let i=j*4
      var factor=Double(a[j])/255
      if let test, !test(Int(p[i]),Int(p[i+1]),Int(p[i+2])) { factor=0 }
      for c in 0..<4 { r.p[i+c]=UInt8((Double(p[i+c])*factor).rounded()) }
    }
    return r
  }
  func crop(_ rect:CGRect) -> Raster {
    let x=Int(rect.minX), y=Int(rect.minY), width=Int(rect.width), height=Int(rect.height)
    var r=Raster(width,height)
    for row in 0..<height {
      let i=((y+row)*w+x)*4
      r.p.replaceSubrange(row*width*4..<(row+1)*width*4,with:p[i..<i+width*4])
    }
    return r
  }
  func rotated(_ degrees:Double, around pivot:[Double]) -> Raster {
    var r=Raster(w,h);let width=w,height=h,im=image()
    r.p.withUnsafeMutableBytes { raw in
      let c=CGContext(data:raw.baseAddress,width:width,height:height,bitsPerComponent:8,bytesPerRow:width*4,
        space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
      let py=Double(height)-pivot[1]
      c.translateBy(x:pivot[0],y:py);c.rotate(by:-degrees*Double.pi/180);c.translateBy(x:-pivot[0],y:-py)
      c.draw(im,in:CGRect(x:0,y:0,width:width,height:height))
    };return r
  }
  func bounds() -> CGRect {
    var x0=w,y0=h,x1=0,y1=0
    for y in 0..<h { for x in 0..<w where p[(y*w+x)*4+3]>8 {
      x0=min(x0,x);y0=min(y0,y);x1=max(x1,x);y1=max(y1,y)
    }}
    precondition(x0<=x1,"Empty part")
    x0=max(0,x0-3); y0=max(0,y0-3); x1=min(w-1,x1+3); y1=min(h-1,y1+3)
    return CGRect(x:x0,y:y0,width:x1-x0+1,height:y1-y0+1)
  }
}
func coverage(_ path:CGPath,_ w:Int,_ h:Int)->[UInt8] {
  var rgba=[UInt8](repeating:0,count:w*h*4)
  rgba.withUnsafeMutableBytes { raw in
    let c=CGContext(data:raw.baseAddress,width:w,height:h,bitsPerComponent:8,bytesPerRow:w*4,
      space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
    c.translateBy(x:0,y:CGFloat(h));c.scaleBy(x:1,y:-1)
    c.addPath(path);c.setFillColor(CGColor(gray:1,alpha:1));c.fillPath()
  }
  return stride(from:3,to:rgba.count,by:4).map{rgba[$0]}
}
func poly(_ pts:[(Double,Double)])->CGPath {
  let p=CGMutablePath();p.move(to:CGPoint(x:pts[0].0,y:pts[0].1))
  for v in pts.dropFirst(){p.addLine(to:CGPoint(x:v.0,y:v.1))};p.closeSubpath();return p
}
func rect(_ x:Double,_ y:Double,_ w:Double,_ h:Double)->CGPath {
  CGPath(rect:CGRect(x:x,y:y,width:w,height:h),transform:nil)
}
func oval(_ x:Double,_ y:Double,_ w:Double,_ h:Double)->CGPath {
  CGPath(ellipseIn:CGRect(x:x,y:y,width:w,height:h),transform:nil)
}
func over(_ back:Raster,_ front:Raster)->Raster {
  var r=back
  for i in stride(from:0,to:r.p.count,by:4) {
    let inv=255-Int(front.p[i+3])
    for c in 0..<4 { r.p[i+c]=UInt8(min(255,Int(front.p[i+c])+Int(back.p[i+c])*inv/255)) }
  };return r
}
func replace(_ original:Raster,_ paint:Raster,_ paths:[CGPath], feather: Int = 0)->Raster {
  var r=original
  for path in paths {
    var mask=coverage(path,r.w,r.h)
    if feather>0 {
      // Inward feather: never touch a pixel outside the selected edit window.
      var dist=mask.map{$0>0 ? 10000 : 0}
      for y in 1..<r.h {for x in 1..<r.w {
        let j=y*r.w+x;dist[j]=min(dist[j],min(dist[j-1],dist[j-r.w])+1)
      }}
      for y in stride(from:r.h-2,through:0,by:-1) {for x in stride(from:r.w-2,through:0,by:-1) {
        let j=y*r.w+x;dist[j]=min(dist[j],min(dist[j+1],dist[j+r.w])+1)
      }}
      for j in mask.indices {
        let t=min(1,Double(dist[j])/Double(feather))
        mask[j]=UInt8(Double(mask[j])*t*t*(3-2*t))
      }
    }
    for j in 0..<r.w*r.h where mask[j]>0 {
      let i=j*4, a=Int(mask[j])
      for c in 0..<4 { r.p[i+c]=UInt8((Int(paint.p[i+c])*a+Int(r.p[i+c])*(255-a))/255) }
    }
  };return r
}
let source=Raster(root.appendingPathComponent("reference.png"))
let master=source.keyed()
let face=Raster(root.appendingPathComponent("face-underpainting.png")).keyed()
let body=Raster(root.appendingPathComponent("body-underpainting.png")).keyed()
precondition(source.w==1254 && source.h==1254,"Masks calibrated to original master")
precondition(face.w==source.w && face.h==source.h && body.w==source.w && body.h==source.h)
let leftEyeWindow=oval(342,189,219,211)
let rightEyeWindow=oval(654,269,210,225)
let leftBrowWindow=rect(432,132,104,54)
let rightBrowWindow=rect(738,199,120,87)
let mouthWindow=poly([(444,393),(485,414),(566,446),(674,452),(684,487),(604,497),(507,470),(449,425)])
let eyeTest:(Int,Int,Int)->Bool = {r,g,b in (r>170 && g>170 && b>150) || (r>g+18 && g<160) || (g<110 && r<100 && b<90)}
let eyeLeft=master.masked(rect(352,203,204,190),test:eyeTest).largestComponent().filledHoles()
let eyeRight=master.masked(rect(665,283,194,205),test:eyeTest).largestComponent().filledHoles()
let browLeft=master.masked(leftBrowWindow,test:{r,g,b in g<120 && r<120 && b<90})
let browRight=master.masked(rightBrowWindow,test:{r,g,b in g<120 && r<120 && b<90})
let smile=master.masked(mouthWindow,test:{r,g,b in r>g+30 && r>b+40 && g<150})
// Replace only pixels owned by removable marks. Re-layering those original
// marks restores every surrounding master pixel, with no rectangular patches.
var blankFace=replace(master,face,[oval(326,169,248,250),oval(635,251,243,260),rect(422,123,124,76),rect(727,192,141,104)],feather:24)
for feature in [eyeLeft,eyeRight,browLeft,browRight,smile] {
  for i in stride(from:0,to:master.p.count,by:4) where feature.p[i+3]>0 {
    blankFace.p[i..<i+4]=face.p[i..<i+4]
  }
}
for feature in [eyeLeft,eyeRight,browLeft,browRight] {
  let b=feature.bounds()
  for y in max(5,Int(b.minY)-2)..<min(master.h-5,Int(b.maxY)+2) {
    for x in max(5,Int(b.minX)-2)..<min(master.w-5,Int(b.maxX)+2) {
      let i=(y*master.w+x)*4
      if feature.p[i+3]>0 {continue}
      var distance=10
      for dy in -4...4 {for dx in -4...4 {
        if feature.p[((y+dy)*master.w+x+dx)*4+3]>0 {distance=min(distance,max(abs(dx),abs(dy)))}
      }}
      if distance<=4 {
        let a=Double(5-distance)/4
        for c in 0..<4 {blankFace.p[i+c]=UInt8(Double(face.p[i+c])*a+Double(blankFace.p[i+c])*(1-a))}
      }
    }
  }
}
// Remove antialiased red residue around the smile so alternate speech mouths
// never reveal a second, faint resting smile underneath them.
for y in 396..<491 {for x in 447..<676 {
  let j=y*master.w+x, i=j*4
  if smile.p[i+3]>0 {continue}
  var distance=10
  for dy in -4...4 {for dx in -4...4 {
    if smile.p[((y+dy)*master.w+x+dx)*4+3]>0 {distance=min(distance,max(abs(dx),abs(dy)))}
  }}
  if distance<=4 {
    let a=Double(5-distance)/4
    for c in 0..<4 {blankFace.p[i+c]=UInt8(Double(face.p[i+c])*a+Double(master.p[i+c])*(1-a))}
  }
}}
blankFace=replace(blankFace,master,[oval(509,373,23,32),oval(605,400,25,31),rect(294,281,58,69),rect(851,385,55,101)])
for window in [rect(309,344,93,73),rect(715,480,116,66)] {
  let blush=master.masked(window,test:{r,g,b in r>200 && r>g+55 && g>90 && b<140})
  for i in stride(from:0,to:master.p.count,by:4) where blush.p[i+3]>0 {blankFace.p[i..<i+4]=master.p[i..<i+4]}
}
// Head boundary follows the master jaw. A rounded underpainted neck tucks beneath scarf.
let headPath=CGMutablePath()
headPath.move(to:CGPoint(x:240,y:70));headPath.addLine(to:CGPoint(x:936,y:70))
headPath.addLine(to:CGPoint(x:936,y:510))
headPath.addCurve(to:CGPoint(x:672,y:591),control1:CGPoint(x:890,y:576),control2:CGPoint(x:801,y:595))
headPath.addCurve(to:CGPoint(x:443,y:551),control1:CGPoint(x:570,y:594),control2:CGPoint(x:494,y:576))
headPath.addLine(to:CGPoint(x:265,y:455));headPath.closeSubpath()
let neck=body.masked(oval(480,550,196,80))
var parts:[String:Raster]=[:]
var headOnly=blankFace.masked(headPath)
for y in 541..<630 {for x in 260..<940 {
  let i=(y*headOnly.w+x)*4
  if Int(headOnly.p[i])>Int(headOnly.p[i+1])+45 {for c in 0..<4 {headOnly.p[i+c]=0}}
}}
parts["Head"]=over(neck,headOnly).largestComponent()
// An edit can shift a handful of edge pixels. Lock the actual head outline to
// the original master, independent of the generated underpainting's alpha.
if var h=parts["Head"] {
  for y in 0..<541 {for x in 240..<940 {
    let i=(y*master.w+x)*4,old=Int(h.p[i+3]),target=Int(master.p[i+3])
    if old==0 && target>0 {h.p[i..<i+4]=master.p[i..<i+4]} else {
      for c in 0..<3 {h.p[i+c]=old>0 ? UInt8(min(255,Int(h.p[i+c])*target/old)) : 0}
      h.p[i+3]=UInt8(target)
    }
  }};parts["Head"]=h
}
// Body underpainting is used only where the original scarf/arms occlude torso.
let torsoPath=CGMutablePath()
torsoPath.move(to:CGPoint(x:500,y:553))
torsoPath.addCurve(to:CGPoint(x:658,y:565),control1:CGPoint(x:533,y:527),control2:CGPoint(x:629,y:533))
torsoPath.addCurve(to:CGPoint(x:716,y:877),control1:CGPoint(x:647,y:673),control2:CGPoint(x:671,y:775))
torsoPath.addCurve(to:CGPoint(x:657,y:987),control1:CGPoint(x:733,y:931),control2:CGPoint(x:711,y:981))
torsoPath.addCurve(to:CGPoint(x:425,y:879),control1:CGPoint(x:552,y:1007),control2:CGPoint(x:447,y:950))
torsoPath.addCurve(to:CGPoint(x:500,y:553),control1:CGPoint(x:384,y:775),control2:CGPoint(x:415,y:649))
torsoPath.closeSubpath()
let la=CGMutablePath()
la.move(to:CGPoint(x:413,y:620))
la.addCurve(to:CGPoint(x:474,y:651),control1:CGPoint(x:444,y:589),control2:CGPoint(x:480,y:617))
la.addCurve(to:CGPoint(x:388,y:797),control1:CGPoint(x:455,y:700),control2:CGPoint(x:414,y:766))
for q in [(407.0,859.0),(397,907),(223,909),(217,780),(310,749),(379,665)] {la.addLine(to:CGPoint(x:q.0,y:q.1))}
la.closeSubpath()
let greenOnly:(Int,Int,Int)->Bool = { r,g,b in !(r>g+40 && b<110) }
parts["ArmLeft"]=master.masked(la,test:greenOnly)
let ra=CGMutablePath()
ra.move(to:CGPoint(x:646,y:677))
ra.addCurve(to:CGPoint(x:696,y:680),control1:CGPoint(x:646,y:652),control2:CGPoint(x:690,y:650))
ra.addLine(to:CGPoint(x:757,y:785));ra.addLine(to:CGPoint(x:817,y:800))
ra.addCurve(to:CGPoint(x:869,y:841),control1:CGPoint(x:858,y:805),control2:CGPoint(x:880,y:824))
ra.addCurve(to:CGPoint(x:848,y:864),control1:CGPoint(x:870,y:858),control2:CGPoint(x:859,y:868))
ra.addLine(to:CGPoint(x:841,y:867))
ra.addCurve(to:CGPoint(x:855,y:893),control1:CGPoint(x:855,y:871),control2:CGPoint(x:860,y:881))
ra.addCurve(to:CGPoint(x:829,y:916),control1:CGPoint(x:855,y:909),control2:CGPoint(x:842,y:921))
ra.addLine(to:CGPoint(x:804,y:906))
ra.addCurve(to:CGPoint(x:778,y:930),control1:CGPoint(x:803,y:925),control2:CGPoint(x:793,y:934))
ra.addCurve(to:CGPoint(x:752,y:897),control1:CGPoint(x:758,y:929),control2:CGPoint(x:748,y:913))
ra.addLine(to:CGPoint(x:742,y:888))
ra.addCurve(to:CGPoint(x:699,y:875),control1:CGPoint(x:722,y:908),control2:CGPoint(x:697,y:895))
ra.addCurve(to:CGPoint(x:714,y:844),control1:CGPoint(x:695,y:858),control2:CGPoint(x:706,y:847))
for q in [(708.0,823.0),(706,789),(686,750),(671,712),(659,687)] {ra.addLine(to:CGPoint(x:q.0,y:q.1))}
ra.closeSubpath()
// Keep pads (orange) on the hands; exclude scarf only at the shoulder.
parts["ArmRight"]=master.masked(ra)
if var a=parts["ArmRight"] {
  for y in 640..<735 {for x in 620..<725 {
    let i=(y*a.w+x)*4
    if Int(a.p[i])>Int(a.p[i+1])+40 {for c in 0..<4 {a.p[i+c]=0}}
  }};parts["ArmRight"]=a
}
// Restore left hand pads excluded by the shoulder color guard.
parts["ArmLeft"]=over(parts["ArmLeft"]!,master.masked(poly([(220,770),(388,770),(407,865),(393,905),(217,909)]))).largestComponent()
if var a=parts["ArmLeft"] {
  for y in 600..<785 {for x in 385..<480 {
    let i=(y*a.w+x)*4
    if a.p[i]>200 && a.p[i+1]>180 && a.p[i+2]>100 {for c in 0..<4 {a.p[i+c]=0}}
  }};parts["ArmLeft"]=a.largestComponent()
}
let ll=CGMutablePath()
ll.move(to:CGPoint(x:409,y:906))
ll.addCurve(to:CGPoint(x:544,y:912),control1:CGPoint(x:396,y:815),control2:CGPoint(x:546,y:829))
for q in [(544.0,1007.0),(585,1053),(581,1179),(313,1179),(317,1040),(392,1029)] {ll.addLine(to:CGPoint(x:q.0,y:q.1))}
ll.closeSubpath();parts["LegLeft"]=master.masked(ll)
let lr=CGMutablePath()
lr.move(to:CGPoint(x:633,y:915))
lr.addCurve(to:CGPoint(x:773,y:918),control1:CGPoint(x:626,y:824),control2:CGPoint(x:767,y:830))
for q in [(803.0,1026.0),(903,1045),(900,1187),(641,1189),(629,1063)] {lr.addLine(to:CGPoint(x:q.0,y:q.1))}
lr.closeSubpath();parts["LegRight"]=master.masked(lr)
let tailPath=CGMutablePath()
tailPath.move(to:CGPoint(x:790,y:860));tailPath.addLine(to:CGPoint(x:837,y:852))
for q in [(863.0,840.0),(854,605),(1148,599),(1169,1026),(809,1026)] {tailPath.addLine(to:CGPoint(x:q.0,y:q.1))}
tailPath.addCurve(to:CGPoint(x:746,y:939),control1:CGPoint(x:769,y:1003),control2:CGPoint(x:732,y:975))
tailPath.addCurve(to:CGPoint(x:790,y:860),control1:CGPoint(x:731,y:887),control2:CGPoint(x:763,y:857));tailPath.closeSubpath()
var tailBase=master
for i in stride(from:0,to:master.p.count,by:4) where parts["ArmRight"]!.p[i+3]>0 {
  tailBase.p[i..<i+4]=body.p[i..<i+4]
}
parts["Tail"]=tailBase.masked(tailPath)
// The root lies behind the original thigh. Extend the existing painted tail
// material into a rounded overlap, then keep all exposed tail pixels intact.
var rootPaint=Raster(master.w,master.h)
let rootMask=coverage(oval(752,869,108,109),master.w,master.h)
let torsoCoverage=coverage(torsoPath,master.w,master.h)
for y in 869..<978 {for x in 752..<860 {
  let j=y*master.w+x,i=j*4, sx=max(820,x+60), si=(y*master.w+sx)*4
  guard rootMask[j]>0,body.p[si+3]>0,(parts["LegRight"]!.p[i+3]>128 || torsoCoverage[j]>128) else {continue}
  for c in 0..<4 {rootPaint.p[i+c]=UInt8(Int(body.p[si+c])*Int(rootMask[j])/255)}
}}
var exposedTail=parts["Tail"]!
for y in 850..<1028 {for x in 700..<861 {
  let i=(y*master.w+x)*4
  if parts["LegRight"]!.p[i+3]>128 || torsoCoverage[y*master.w+x]>128 {
    for c in 0..<4 {exposedTail.p[i+c]=0}
  }
}}
parts["Tail"]=over(rootPaint,exposedTail)
parts["Scarf"]=master.masked(poly([(428,536),(501,557),(647,590),(730,584),(785,570),(855,575),(860,726),(560,726),(452,640)]),test:{r,g,b in r>g+55 && r>b+60}).largestComponent()
// The body edit supplies continuous shoulders and sides beneath moving arms.
// Use the edited shoulder/side skin, preserving the exposed central belly.
// A broad shoulder fill also removes original arm-edge antialiasing when an
// arm rotates away from the torso.
let torsoBase=replace(body,master,[rect(475,746,139,180)],feather:12)
parts["Body"]=torsoBase.masked(torsoPath)
parts["EyeLeft"]=eyeLeft;parts["EyeRight"]=eyeRight
parts["BrowLeft"]=browLeft;parts["BrowRight"]=browRight;parts["Smile"]=smile
let pivots:[String:[Double]]=["Head":[583,586],"Body":[568,932],"ArmLeft":[445,641],"ArmRight":[671,697],"LegLeft":[477,916],"LegRight":[704,921],"Tail":[785,920],"Scarf":[592,610],"EyeLeft":[456,295],"EyeRight":[760,388],"BrowLeft":[485,159],"BrowRight":[795,233],"Smile":[558,445]]
let order=["Tail","LegLeft","LegRight","Body","ArmLeft","ArmRight","Head","Scarf","EyeLeft","EyeRight","BrowLeft","BrowRight","Smile"]
let directParts=["ArmLeft","ArmRight","LegLeft","LegRight","Scarf","EyeLeft","EyeRight","BrowLeft","BrowRight","Smile"]
// Canonicalize fully covered master samples after mask union, which can round
// an opaque edge by one channel value when two antialiased masks overlap.
for name in directParts {
  var im=parts[name]!
  for i in stride(from:0,to:im.p.count,by:4) where im.p[i+3]==255 {
    im.p[i..<i+4]=master.p[i..<i+4]
  };parts[name]=im
}
var manifest:[String:Any]=[:]
for name in order {
  let im=parts[name]!, b=im.bounds(), pivot=pivots[name]!
  try im.save("rig/\(name).png",magenta:true)
  try im.save("rig-alpha/\(name).png")
  try im.crop(b).save("rig-cropped/\(name).png")
  manifest[name]=["x":Int(b.minX),"y":Int(b.minY),"width":Int(b.width),"height":Int(b.height),
    "pivotX":pivot[0],"pivotY":pivot[1],"localPivotX":pivot[0]-b.minX,"localPivotY":pivot[1]-b.minY]
}
var assembled=Raster(master.w,master.h)
for name in order {assembled=over(assembled,parts[name]!)}
try assembled.save("review/assembled.png",magenta:true)
var motion=Raster(master.w,master.h)
for name in order {
  var im=parts[name]!
  if ["Head","EyeLeft","EyeRight","BrowLeft","BrowRight","Smile"].contains(name) {im=im.rotated(-8,around:pivots["Head"]!)}
  if name=="ArmLeft" {im=im.rotated(12,around:pivots[name]!)}
  if name=="ArmRight" {im=im.rotated(-12,around:pivots[name]!)}
  if name=="Tail" {im=im.rotated(6,around:pivots[name]!)}
  motion=over(motion,im)
}
try motion.save("review/joint-motion-check.png",magenta:true)
try master.save("review/master-keyed.png",magenta:true)
try master.save("review/master-transparent.png")
var exactChecks:[String:Int]=[:]
var changedChecks:[String:Int]=[:]
for name in directParts {
  let im=parts[name]!
  var count=0,changed=0
  for i in stride(from:0,to:im.p.count,by:4) where im.p[i+3]==255 {
    if im.p[i]==master.p[i] && im.p[i+1]==master.p[i+1] && im.p[i+2]==master.p[i+2] {count+=1} else {changed+=1}
  };exactChecks[name]=count;changedChecks[name]=changed
}
var silhouetteMismatch=0
for y in 0..<541 {for x in 240..<940 {
  let i=(y*master.w+x)*4
  if (master.p[i+3]>128) != (parts["Head"]!.p[i+3]>128) {silhouetteMismatch+=1}
}}
let checks:[String:Any]=["headSilhouetteMismatchPixelsAboveJaw":silhouetteMismatch,"exactMasterOpaquePixelsByPart":exactChecks,"opaqueEdgeRoundingDifferencesByPart":changedChecks,"masterCanvasUnscaled":true]
precondition(silhouetteMismatch==0,"Head contour must match the master")
precondition(changedChecks.values.allSatisfy{$0==0},"Direct cutouts must preserve master pixel colors")
try JSONSerialization.data(withJSONObject:checks,options:[.prettyPrinted,.sortedKeys]).write(to:root.appendingPathComponent("rig-validation.json"))
let info:[String:Any]=["canvasWidth":master.w,"canvasHeight":master.h,"coordinateOrigin":"top-left","drawOrder":order,"parts":manifest]
try JSONSerialization.data(withJSONObject:info,options:[.prettyPrinted,.sortedKeys]).write(to:root.appendingPathComponent("rig-manifest.json"))
print("Extracted \(parts.count) aligned parts; native master canvas \(master.w) × \(master.h)")

// Register all mouths once against the actual extracted master smile. Preserve
// generated source files so rerunning never transforms an already aligned PNG.
try fm.createDirectory(at:root.appendingPathComponent("mouth-sources"),withIntermediateDirectories:true)
let widths:[Double]=[207,207,207,207,207,94,47,228,207,207,207,228]
let depths:[Double]=[0,15,27,53,88,76,43,46,9,7,66,55]
var mouthManifest:[[String:Any]]=[]
for n in 0..<12 {
  let file=String(format:"mouth-%02d.png",n)
  let originalURL=root.appendingPathComponent("mouth-sources/\(file)")
  if !fm.fileExists(atPath:originalURL.path) {
    try fm.copyItem(at:root.appendingPathComponent("mouths/\(file)"),to:originalURL)
  }
  var output=Raster(master.w,master.h)
  if n==0 {output=smile} else {
    let input=Raster(originalURL).keyed(), b=input.bounds()
    var tops=[Int:Int]()
    for x in Int(b.minX)..<Int(b.maxX) {
      for y in Int(b.minY)..<Int(b.maxY) where input.p[(y*input.w+x)*4+3]>100 {
        tops[x]=y;break
      }
    }
    let xs=tops.keys.sorted(), count=xs.count
    precondition(count>10)
    func average(_ indices:Range<Int>)->(Double,Double) {
      let cols=indices.map{xs[$0]}
      return (Double(cols.reduce(0,+))/Double(cols.count),Double(cols.map{tops[$0]!}.reduce(0,+))/Double(cols.count))
    }
    let l=average(max(0,count/50)..<max(1,count/12))
    let r=average(min(count-1,count*11/12)..<min(count,count*49/50))
    let slope=(r.1-l.1)/(r.0-l.0)
    let sx0=Double(xs.first!), sx1=Double(xs.last!)
    let sy0=l.1+slope*(sx0-l.0)
    var minV=Double.greatestFiniteMagnitude, maxV = -Double.greatestFiniteMagnitude
    for x in xs {for y in Int(b.minY)..<Int(b.maxY) where input.p[(y*input.w+x)*4+3]>100 {
      let v=Double(y)-sy0-slope*(Double(x)-sx0)
      minV=min(minV,v);maxV=max(maxV,v)
    }}
    let targetWidth=widths[n], depth=depths[n]
    let left=560-targetWidth/2, top=432-(targetWidth/2)*(59.0/206.0)
    let xScale=targetWidth/(sx1-sx0), yScale=depth/max(1,maxV-minV)
    // Inverse mapping with bilinear sampling in premultiplied RGBA.
    for y in 350..<580 {for x in 420..<705 {
      let u=(Double(x)-left)/xScale
      let v=(Double(y)-top-(Double(x)-left)*(59.0/206.0))/yScale+minV
      let ix=sx0+u, iy=sy0+slope*u+v
      let x0=Int(floor(ix)), y0=Int(floor(iy))
      guard x0>=0,y0>=0,x0+1<input.w,y0+1<input.h else {continue}
      let fx=ix-Double(x0), fy=iy-Double(y0), to=(y*output.w+x)*4
      for c in 0..<4 {
        let a=Double(input.p[(y0*input.w+x0)*4+c]),bb=Double(input.p[(y0*input.w+x0+1)*4+c])
        let cc=Double(input.p[((y0+1)*input.w+x0)*4+c]),d=Double(input.p[((y0+1)*input.w+x0+1)*4+c])
        output.p[to+c]=UInt8(max(0,min(255,((a*(1-fx)+bb*fx)*(1-fy)+(cc*(1-fx)+d*fx)*fy).rounded())))
      }
    }}
  }
  try output.save("mouths/\(file)",magenta:true)
  try output.save("mouths-alpha/\(file)")
  let b=output.bounds()
  try output.crop(b).save("mouths-cropped/\(file)")
  mouthManifest.append(["file":file,"x":Int(b.minX),"y":Int(b.minY),"width":Int(b.width),"height":Int(b.height),"articulationDepth":depths[n]])
  // Full-character previews expose size, angle and expression problems.
  var pose=Raster(master.w,master.h)
  for name in order where name != "Smile" {pose=over(pose,parts[name]!)}
  pose=over(pose,output)
  try pose.save("review/\(file)",magenta:true)
}
try JSONSerialization.data(withJSONObject:mouthManifest,options:[.prettyPrinted,.sortedKeys]).write(to:root.appendingPathComponent("mouth-manifest.json"))
print("Registered 12 mouths against the exact master smile")
