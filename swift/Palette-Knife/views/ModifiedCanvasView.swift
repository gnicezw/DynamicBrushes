//
//  ModifiedCanvasView.swift
//  PaletteKnife
//
//  Created by JENNIFER MARY JACOBS on 4/29/17.
//  Copyright © 2017 pixelmaid. All rights reserved.
//

import Foundation
import UIKit

let pi = Float.pi

class ModifiedCanvasView: UIView, JotViewDelegate,JotViewStateProxyDelegate {
    //TODO: these are extraneous, should remove them
    var jotViewStateInkPath: String!
    var jotViewStatePlistPath:String!
    
    var id = NSUUID().uuidString;
    let name:String?
    var drawActive = true;
    var jotView:JotView!
    //JotView params
   
    var numberOfTouches:Int = 0
    var lastLoc:CGPoint!
    var lastDate:NSDate!
    var velocity = 0;
    var activeStrokes = [String:JotStroke]();
    var allStrokes = [JotStroke]();
    var eraseStroke:JotStroke!
    var saveEvent = Event<(String,String,UIImage?,UIImage?,JotViewImmutableState?)>();
    //end JotView params
    
    init(name:String,frame:CGRect){
        self.name = name
        jotView = JotView(frame:frame);
        super.init(frame:frame)
        
        jotView.delegate = self
        _ = self.jotViewStateInkPathFunc();
        _ = self.jotViewStatePlistPathFunc();
        _ = self.jotViewStateThumbPathFunc();
    
        let paperState = JotViewStateProxy(delegate: self)
        paperState?.loadJotStateAsynchronously(false, with: jotView.bounds.size, andScale: jotView.scale, andContext: jotView.context, andBufferManager: JotBufferManager.sharedInstance())
        jotView.loadState(paperState)
        self.addSubview(jotView)
        
    }
    
    
    deinit{
        self.removeAllStrokes();
        #if DEBUG
        print("dealocated layer \(self.id)")
        #endif

    }
    
   
    
    required init?(coder aDecoder: NSCoder) {
        self.name = "noname";
        
        super.init(coder: aDecoder)
        let size = self.frame.size
        jotView = JotView(frame:CGRect(x:0,y:0,width:size.width,height:size.height));
    }
    
    func beginStroke(id:String){
        if(!self.isHidden){
           
            autoreleasepool {
                if(jotView.state == nil){
                    #if DEBUG
                        print("state is nil")
                    #endif
                    return;
                }
                let newStroke = JotStroke(texture: self.textureForStroke(), andBufferManager: jotView.state.bufferManager());
                newStroke!.delegate = jotView as JotStrokeDelegate;
                
                if(id == "eraseStroke"){
                    eraseStroke = newStroke;
                }
                else{
                    activeStrokes[id] = newStroke!;
                    allStrokes.append(newStroke!)
                }
            }
            JotGLContext.validateEmptyStack()
        }
    }
    
    func removeAllStrokes(){
        for value in allStrokes{
            value.lock();
            value.empty();
            value.unlock();
            
        }
        self.allStrokes.removeAll();
        self.activeStrokes.removeAll();
        JotGLContext.validateEmptyStack();
    }
    
    func renderStrokeById(currentStrokeId: String, toPoint:CGPoint,toWidth:CGFloat,toColor:UIColor!){
        guard let currentStroke:JotStroke = activeStrokes[currentStrokeId] else {return}
        self.renderStroke(currentStroke: currentStroke, toPoint: toPoint, toWidth: toWidth, toColor: toColor)
    }
    
    func renderStroke(currentStroke:JotStroke,toPoint:CGPoint,toWidth:CGFloat,toColor:UIColor!){
        #if DEBUG
            //print("draw interval render stroke",toPoint)
        #endif
        if(!self.isHidden){
           
                if(jotView.state == nil){
                    #if DEBUG
                        print("state is nil")
                    #endif
                    return;
                }
                
            currentStroke.lock();
             autoreleasepool {
                   _ = jotView.addLine(toAndRenderStroke: currentStroke, to: toPoint, toWidth: toWidth*4, to: toColor, andSmoothness: self.getSmoothness(), withStepWidth: self.stepWidthForStroke())
                    
                
            
            }
            currentStroke.unlock();
                JotGLContext.validateEmptyStack();

            
        }
    }
    
    
    func endAllStrokes(){
         #if DEBUG
            
        print("ending all strokes",self.activeStrokes,self.activeStrokes.count)
            #endif
        
        
        
        for (id, value) in self.activeStrokes{
            if(value.segments.count > 0){
                self.endStroke(currentStroke: value)
                activeStrokes.removeValue(forKey: id)
            }
        }
        #if DEBUG
            print("strokes remaining",self.activeStrokes,self.activeStrokes.count)
        #endif
       

    }
    
    func endStrokes(idList:[String]){
        #if DEBUG
            
            print("total number of active jot view strokes",id, activeStrokes.count,activeStrokes);
            
        #endif
        for id in idList{
            #if DEBUG
            print("ending strokes",id,activeStrokes[id]);
            #endif
            let stroke =  activeStrokes[id]
            if(stroke != nil){
                endStroke(currentStroke: stroke!)
                activeStrokes.removeValue(forKey: id)
            }
        }
        
    }
    
    func endStroke(currentStroke:JotStroke){
        autoreleasepool {
            currentStroke.lock();
            jotView.state.currentStroke =  currentStroke;
            jotView.state.finishCurrentStroke();
            currentStroke.unlock();
        }
        JotGLContext.validateEmptyStack();
    }
    
    
    func layerTouchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }

        if touch.type == .stylus {
            if(drawActive){
                if let touch = touches.first  {
                    let point = touch.location(in: self)
                    let x = Float(point.x)
                    let y = Float(point.y)
                    let force = Float(touch.force);
                    let angle = Float(touch.azimuthAngle(in: self))
                    stylus.onStylusDown(x: x, y:y, force:force, angle:angle)
                }
            }
            else {
                self.beginStroke(id:"eraseStroke")
            }
        }
    }
    
    
    
    func saveUIImageAndState(){
        self.endAllStrokes();
        let stateImage: ((UIImage?, UIImage?, JotViewImmutableState?) -> Void)! = imageStateSaveComplete
        jotView.exportImage(to: self.jotViewStateInkPathFunc(), andThumbnailTo:self.jotViewStateThumbPathFunc(), andStateTo: self.jotViewStatePlistPathFunc(), withThumbnailScale:1.0, onComplete: stateImage)
    }

    
    //handler called when state is saved
    func imageStateSaveComplete(ink:UIImage?, thumb:UIImage?, state:JotViewImmutableState?){
        if(thumb != nil && ink != nil && state != nil){
        self.saveEvent.raise(data: ("COMPLETE",self.id,thumb!,ink!,state!));
        }
        else{
            self.saveEvent.raise(data: ("INCOMPLETE",self.id,nil,nil,nil));

        }
    }
    
    
    //returns a list of all saved strokes in the state
    func getSavedStrokes()->[String]{
        var strokeList = [String]();

        for value in allStrokes{
            if value.uuid() != "1" {
            strokeList.append(value.uuid());
            }
        }
      
        return strokeList;
    }

    
    
    func loadNewState() {
        self.removeAllStrokes();
        _ = jotViewStateInkPathFunc();
        _ = jotViewStatePlistPathFunc();
        _ = jotViewStateThumbPathFunc();
        print("load new state called",self.jotViewStatePlistPath,self.jotViewStateInkPath)
        jotView.state.isForgetful = true
        let state = JotViewStateProxy(delegate:self);
        state?.loadJotStateAsynchronously(false, with: jotView.bounds.size, andScale: 1.0, andContext: jotView.context, andBufferManager: JotBufferManager.sharedInstance())
        jotView.loadState(state)
        
        let v_strokes = state?.everyVisibleStroke();
        #if DEBUG
        print("visible strokes",v_strokes as Any);
        #endif
        
        for s in v_strokes!{
            guard let stroke = s as? JotStroke else { return }
           
            self.allStrokes.append(stroke)
            
        }
        
        print("strokes after load = ",self.allStrokes);
        
    }

    
    func pushContext()->ModifiedCanvasView{
        return self;
    }
    
    
    func layerTouchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        var touches = [UITouch]()
        if let coalescedTouches = event?.coalescedTouches(for: touch) {
            touches = coalescedTouches
        } else {
            touches.append(touch)
        }
        #if DEBUG
            //print("number of coalesced touches \(touches.count)");
        #endif
         if touch.type == .stylus {
        if(drawActive){
            
            for touch in touches {
                let location = touch.location(in: self)
                let x = Float(location.x);
                let y = Float(location.y);
                let force = Float(touch.force);
                let angle = Float(touch.azimuthAngle(in: self))
                //let mappedAngle = MathUtil.map(value: angle, low1: 0, high1: 2*Float.pi, low2: 0, high2: 1);
                stylus.onStylusMove(x: x, y:y, force:force, angle:angle);
                
            }
        }
            //Erase mode
        else {
            
            let location = touch.location(in: self)
            let width = CGFloat(uiInput.diameter.get(id: nil));
            self.renderStroke(currentStroke: eraseStroke, toPoint: location, toWidth: width, toColor: nil)
        }
        }
        
        
        
    }
    
    func eraseCanvas(context:CGContext, start:CGPoint,end:CGPoint,force:CGFloat){
        
        context.setStrokeColor(UIColor.red.cgColor)
        //TODO: will need to fine tune this
        context.setLineWidth(CGFloat(uiInput.diameter.get(id: nil)))
        context.setLineCap(.round)
        context.setAlpha(CGFloat(1));
        context.setBlendMode(CGBlendMode.clear)
        
        context.move(to: start)
        
        context.addLine(to:end)
        context.strokePath()
    }
    
    
    func layerTouchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        stylus.onStylusUp()
        if drawActive == false {
            if eraseStroke != nil{
                self.endStroke(currentStroke: eraseStroke)
                eraseStroke = nil;
            }
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        //image = drawingImage
    }
    
    func eraseAll() {
        jotView.clear(true)
        // self.image = nil
        
    }
    
    
    // #pragma mark - JotViewDelegate
    
    func textureForStroke()->JotBrushTexture {
        return JotDefaultBrushTexture.sharedInstance()
    }
    
    func stepWidthForStroke()->CGFloat {
        return CGFloat(2);
    }
    
    func supportsRotation()->Bool {
        return false
    }
    
    
    func willAddElements(_ elements: [Any]!, to stroke: JotStroke!, fromPreviousElement previousElement: AbstractBezierPathElement!) -> [Any]! {
        return elements
    }
    
    func willBeginStroke(withCoalescedTouch coalescedTouch: UITouch!, from touch: UITouch!) -> Bool {
        
        return true;
    }
    func willMoveStroke(withCoalescedTouch coalescedTouch: UITouch!, from touch: UITouch!) {
        
    }
    
    
    func willEndStroke(withCoalescedTouch coalescedTouch: UITouch!, from touch: UITouch!, shortStrokeEnding: Bool) {
        
    }
    
    func didEndStroke(withCoalescedTouch coalescedTouch: UITouch!, from touch: UITouch!) {
        
    }
    func willCancel(_ stroke: JotStroke!, withCoalescedTouch coalescedTouch: UITouch!, from touch: UITouch!) {
        
    }
    func didCancel(_ stroke: JotStroke!, withCoalescedTouch coalescedTouch: UITouch!, from touch: UITouch!) {
        
    }
    
    func color(forCoalescedTouch coalescedTouch: UITouch!, from touch: UITouch!) -> UIColor! {
        return UIColor.black
        
    }
    
    
    func width(forCoalescedTouch coalescedTouch: UITouch!, from touch: UITouch!) -> CGFloat {
        return 6
        
    }
    
    func smoothness(forCoalescedTouch coalescedTouch: UITouch!, from touch: UITouch!) -> CGFloat {
        return 0.75;
        
    }
    
    func getSmoothness()->CGFloat{
        return 0.75;
    }
    
    //#pragma mark - JotViewStateProxyDelegate
    
    func didLoadState(_ state: JotViewStateProxy!) {
        
    }
    
    func didUnloadState(_ state: JotViewStateProxy!) {
        
    }
    
    
    func jotViewStateInkPathFunc() -> String {
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true) as NSArray
        let documentDirectory = paths[0] as! String
        let path = documentDirectory.appending("/ink_"+id+".png")
        print("ink",path)
        self.jotViewStateInkPath = path;
        return path

    }
    
    func jotViewStateThumbPathFunc() -> String {
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true) as NSArray
        let documentDirectory = paths[0] as! String
        let path = documentDirectory.appending("/thumb_"+id+".png")
        print("thumb",path)
        return path

    }
    
    func jotViewStatePlistPathFunc() -> String {
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true) as NSArray
        let documentDirectory = paths[0] as! String
        let path = documentDirectory.appending("/state_"+id+".plist")
        print("plist",path)
        self.jotViewStatePlistPath = path;

        return path
    }

   


}
