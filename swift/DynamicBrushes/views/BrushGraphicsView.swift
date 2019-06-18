//
//  BrushGraphicsView.swift
//  DynamicBrushes
//
//  Created by Jingyi Li on 5/22/19.
//  Copyright © 2019 pixelmaid. All rights reserved.
//

import Foundation
import Macaw

public class BrushGraphicsScene {
    //a brush graphics scene contains brushgraphics (one for each active brush)
    let view: BrushGraphicsView
    var node: Group
    var activeBrushIds = [String:BrushGraphic]() //dictionary
    
    init(view: BrushGraphicsView) {
        self.view = view
        self.node = Group()
        print("## (2) init BG scene")
    }

    public func addBrushGraphic(id:String, ox:Float, oy:Float, r: Float,
                         x: Float, y:Float, cx: Float, cy:Float ) {
        //add to id, create new class
        let brushGraphic = BrushGraphic(view:self.view, scene:self, id:id, ox:ox, oy:oy, r:r, x:x, y:y, cx:cx, cy:cy)
        self.activeBrushIds[id] = brushGraphic //add to dict
    }
    
    public func updateBrush(id:String, r: Float, x: Float, y: Float, cx: Float, cy: Float, ox: Float, oy: Float, sx:Float, sy:Float) {
        for (_, brush) in self.activeBrushIds {
            if brush.id == id {
                print("## updating brush with id ", id)
                brush.updateBrushIcon(r:r, ox: ox, oy: oy, sx:sx, sy:sy)
                brush.moveComputedLocation(cx: cx, cy: cy)
                brush.moveInputLocation(x: x, y: y)

            }
        }
    }
    
    public func checkActiveId(id:String) -> Bool {
        if (self.activeBrushIds[id] != nil) {
            return true;
        }
        return false;
    }
    
    
    public func removeActiveId(id:String) {
        if let removedBrush = self.activeBrushIds.removeValue(forKey: id) {
            removedBrush.removeFromScene()
            print("## removed id ", id)
        }
    }
    
}

class BrushGraphic {
    //a brush graphic is the atomic unit of a brush graphics scene
    //contains rotation brush icon, and drawing/stylus icons
    
    let view: BrushGraphicsView
    let scene: BrushGraphicsScene
    
    var node: Group
    let brushIcon: Group
    let inputIcon: Shape
    let computedIcon: Shape
    let originText: Text
    let inputText: Text
    let computedText: Text
    let xAxis: Group
    let yAxis: Group
    
    let id: String
    var ox: Float
    var oy: Float
    var r: Float
    var x: Float
    var y: Float
    var cx: Float
    var cy: Float
    
    
    let oxOffset:Double = 0
    let oyOffset:Double = 0
    
    let axisScale:Double = 15
    let axisLen:Double = 50
    var scaleChanged = false
    
    
    let brushColor = Macaw.Color.rgba(r: 255, g:53, b:95, a: 63)
    let outputColor = Macaw.Color.rgba(r: 134, g: 73, b: 180, a: 63)
    
    init(view:BrushGraphicsView, scene:BrushGraphicsScene, id:String, ox:Float, oy:Float, r: Float, x: Float, y:Float,
         cx: Float, cy:Float ) {
        self.id = id
        self.view = view
        self.scene = scene
        self.ox = ox
        self.oy = oy
        self.r = r
        self.x = x
        self.y = y
        self.cx = cx
        self.cy = cy
        
        //add to scene


        //init brush icon
        node = Group()
        
//        let rotationIndicator = Shape (form: Polygon(points: [30,0,35,15,30,30]), fill: brushColor)
//        let originIndicator = Group(contents: [Macaw.Line(x1: 0, y1: 15, x2: 30, y2: 15).stroke(fill: brushColor, width: 2), Macaw.Line(x1: 15, y1: 0, x2: 15, y2: 30).stroke(fill: brushColor, width: 2)])
        let xLine = Shape(form: Macaw.Line(x1: axisScale, y1: 0, x2: axisScale+axisLen, y2:0), stroke: Macaw.Stroke(fill:brushColor, width:2))
        let yLine = Macaw.Line(x1: 0, y1: axisScale, x2: 0, y2:axisScale+axisLen).stroke(fill:brushColor, width:2)
        let triScale = axisScale*0.25
        let xTriangle = Polygon(points:[0, -triScale, -triScale*sqrt(3), 0, 0, triScale]).fill(with: brushColor)
        xTriangle.place = Transform.move(dx:axisScale+axisLen, dy:0).rotate(angle:Double(pi))
        let yTriangle = Polygon(points:[0, -triScale, -triScale*sqrt(3), 0, 0, triScale]).fill(with: brushColor)
        yTriangle.place = Transform.move(dx:0, dy:axisScale+axisLen).rotate(angle:Double(-pi/2))
        
        xAxis = Group(contents:[xLine, xTriangle])
        yAxis = Group(contents:[yLine, yTriangle])
        
        let originCircle = Circle(r:(axisScale*0.33)).stroke(fill:brushColor, width:2)
        let biggerOriginCircle = Circle(r:(axisScale)).stroke(fill:brushColor, width:2)
        originText = BrushGraphic.newText("ox:0, oy:0, r:0\nsx:100, sy:100", Transform.move(dx:0,dy:0))
        let rotArc = Macaw.Arc(ellipse: Ellipse(cx:0,cy:0, rx:axisScale, ry:axisScale),shift: 0, extent: 0).stroke(fill: brushColor, width:10)
        
        brushIcon = Group(contents: [xAxis, yAxis, originCircle, biggerOriginCircle, rotArc])
//        brushIcon.place = Transform.move(dx:Double(self.ox) - oxOffset,dy:Double(self.oy) - oyOffset)
        //for testing
        brushIcon.place = Transform.move(dx:Double(0),dy:Double(0))
        
        node.contents.append(brushIcon)
        node.contents.append(originText)
        print("## init brush icon for brush ", id, " at " , self.ox, self.oy)

        
        //init inputicon
        inputIcon = Shape(form: Circle(r: 10), fill: brushColor, stroke: Macaw.Stroke(fill: Macaw.Color.white, width:2))
        inputIcon.place = Transform.move(dx:Double(self.x), dy:Double(self.y))
        node.contents.append(inputIcon)
        inputText = BrushGraphic.newText("pos x: 0, pos y: 0", Transform.move(dx:0,dy:10))
        node.contents.append(inputText)
        print("## init input icon for brush ", id, " at " , self.x, self.y)

        //init computedicon
        computedIcon = Shape(form: Circle(r: 10), fill: outputColor, stroke: Macaw.Stroke(fill: Macaw.Color.white, width:2))
        computedIcon.place = Transform.move(dx:Double(self.cx), dy:Double(self.cy))
        node.contents.append(computedIcon)
        computedText = BrushGraphic.newText("abs x: 0, abs y: 0", Transform.move(dx:0,dy:20))
        node.contents.append(computedText)
        print("## init computed icon for brush ", id, " at " , self.cx, self.cy)

        
        self.addToScene()
    }
    
    static func newText(_ text: String, _ place: Transform, baseline: Baseline = .bottom) -> Text {
        return Text(text: text, fill: Macaw.Color.black, align: .mid, baseline: baseline, place: place)
    }
    
    func addToScene() {
        self.scene.node.contents.append(self.node)
    }
    
    func removeFromScene() {
        var array = self.scene.node.contents
        if let index = array.index(of:self.node) {
            array.remove(at: index)
            print("## in brush graphic, removed self ", index)
        }
        self.scene.node.contents = array
    }
    
    func updateBrushIcon(r: Float, ox:Float, oy:Float, sx:Float, sy:Float) {
        brushIcon.place = Transform.move(dx: Double(ox) - oxOffset, dy: Double(oy) - oyOffset)
        originText.place = Transform.move(dx: Double(ox), dy: Double(oy) - Double(20))
        self.ox = ox
        self.oy = oy
        self.r = r
        originText.text = "ox:"+String(Int(ox))+", oy:"+String(Int(oy))+", r:"+String(Int(r))
        print("## rotated brush ", self.id, " by ", r, " Moved to ox ,oy,", ox, oy )
        
        //rotate
        let rotArc = Macaw.Arc(ellipse: Ellipse(cx:0,cy:0, rx:axisScale*0.75, ry:axisScale*0.75),shift: 0, extent: Double(r * pi/180)).stroke(fill: brushColor, width:10)
        brushIcon.contents[4] = rotArc
        
        if (sx != 100 || sy != 100 || scaleChanged) {
            originText.text = originText.text + "\nsx:"+String(Int(sx))+"%, sy:"+String(Int(sy))+"%"
            scaleChanged = true
            if (sx != 100) {
                let newLine = Macaw.Line(x1: axisScale, y1: 0, x2: axisScale + (axisLen * Double(sx)/100.0), y2: 0)
                let xLine = xAxis.contents[0] as! Shape
                let animation = xLine.formVar.animation(to: newLine, during: 0.1, delay: 0)
                animation.play()
                let xTri = xAxis.contents[1] as! Shape
                xTri.placeVar.animate(to: Transform.move(dx:(axisScale + axisLen * Double(sx)/100.0), dy: 0).rotate(angle:Double(pi)), during: 0.1, delay: Double(0))
                    //Transform.scale(sx: Double(sx/100.0), sy:1)
                print("## changed x scale")
            }
            if (sy != 100) {
                let newLine = Macaw.Line(x1: 0, y1: axisScale, x2: 0, y2: axisScale + (axisLen * Double(sy)/100.0))
                let yLine = yAxis.contents[0] as! Shape
                let animation = yLine.formVar.animation(to: newLine, during: 0.1, delay: 0)
                animation.play()
                let yTri = yAxis.contents[1] as! Shape
                yTri.placeVar.animate(to: Transform.move(dx:0, dy: (axisScale + axisLen * Double(sy)/100.0)).rotate(angle:Double(-pi/2)), during: 0.1, delay: Double(0))
//                yAxis.contents[0].form = Macaw.Line(x1: 0, y1: (-axisScale * sy/100.0), x2: 0, y2:(3*axisScale * sy/100.0))
                    //Transform.scale(sx: 1, sy: Double(sy/100.0))
                print("## changed y scale")
            }
            if (sx == 100 && sy == 100) {
                scaleChanged = false
            }
        }
    }
    
    
    
    func moveInputLocation(x: Float, y: Float) {
        inputIcon.place = Transform.move(dx: Double(x), dy: Double(y)) //need this offset for some reason?
        self.x = x
        self.y = y
        inputText.text = "pos x: "+String(Int(x))+", pos y: "+String(Int(y))
        inputText.place = Transform.move(dx: Double(x), dy: Double(y) - Double(20))

        print("## moved input" , self.id, " to x ,y,", x, y )
    }
    
    func moveComputedLocation(cx: Float, cy: Float) {
        computedIcon.place = Transform.move(dx: Double(cx), dy: Double(cy))
        self.cx = cx
        self.cy = cy
        computedText.text = "abs x: "+String(Int(cx))+", abs y: "+String(Int(cy))
        computedText.place = Transform.move(dx: Double(cx), dy: Double(cy) + Double(30))

        print("## moved computed" , self.id, "to cx cy" , cx, cy)
    }
    
}

class BrushGraphicsView: MacawView {
    //overall container
    var scene: BrushGraphicsScene?
  
    override init(frame: CGRect) {
        super.init(frame: frame);
        self.backgroundColor =  UIColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 0.0)
        print("## (1) initialized BG view")
        scene = BrushGraphicsScene(view:self)
        self.updateNode()
    }
    
    required init?(coder aDecoder: NSCoder) {
        //this is dummy, it's never called but we need it
        let brushIcon = Shape (form: Polygon(points: [0,0,100,50,0,100,25,50]),
                               fill: Macaw.Color.rgba(r:0, g:0, b:0, a:100))
        super.init(node: Group(contents:[brushIcon]), coder: aDecoder)
    }
    
    func updateNode() {
        let node = scene?.node
        self.node = node!
        print("## called update node in graphics view", self.node)
    }
    
}
