//
//  BehaviorManager.swift
//  PaletteKnife
//
//  Created by JENNIFER MARY JACOBS on 5/25/16.
//  Copyright © 2016 pixelmaid. All rights reserved.
//

import Foundation
import SwiftyJSON

enum BehaviorError: Error {
    case duplicateName
    case behaviorDoesNotExist
    case mappingDoesNotExist;
    case transitionDoesNotExist;
    case requestDoesNotExist;
}

class BehaviorManager{
    static var behaviors = [String:BehaviorDefinition]()
    static var datasets = [String:Table]();
    var canvas:Canvas
    init(canvas:Canvas){
        self.canvas = canvas;
       
    }
    
  
    
    static func getBehaviorById(id:String)->BehaviorDefinition?{
        if(BehaviorManager.behaviors[id] != nil){
            return BehaviorManager.behaviors[id]
        }
        return nil
    }
    
    
    func refreshAllBehaviors(){
        for (_,behavior) in BehaviorManager.behaviors{
            behavior.createBehavior(canvas:canvas)
        }
    }
    
    func loadBehavior(json:JSON){
        self.loadBehaviorsFromJSON(json: json, rewriteAll: true)
    }
    
   
    
    func loadBehaviorsFromJSON(json:JSON,rewriteAll:Bool){
        if(rewriteAll){
            for(_,value) in BehaviorManager.behaviors{
                value.clearBehavior();
            }
            BehaviorManager.behaviors.removeAll();
            
        }
        for(key,value) in json{
            if let val = BehaviorManager.behaviors[key] {
                val.clearBehavior();
                
            }
            let behavior = BehaviorDefinition(id:key,name:value["name"].stringValue);
            behavior.parseJSON(json: value)
            behavior.createBehavior(canvas:canvas);
            BehaviorManager.behaviors[key] = behavior;
            
        }
    }
    
    
    func handleDataRequest(requestData:JSON) ->JSON{
        let data = requestData["data"] as JSON;
        let type = data["type"].stringValue;
        var resultJSON:JSON = [:]
        resultJSON["type"] = JSON("data_request_response");
        resultJSON["request_type"] = JSON(type);
        
        switch(type){
        case "request_existing_mappings":
            let behaviorId = data["behaviorId"].stringValue;
            let stateId = data["stateId"].stringValue;
             let behavior = BehaviorManager.behaviors[behaviorId]!;
            let data = behavior.getMappingsForState(stateId:stateId);
            resultJSON["data"] = data;
            break;
        default:
            break;
            
        }
        
        return resultJSON;
        
    }
    
    func handleAuthoringRequest(authoring_data:JSON) throws->JSON{
        BehaviorManager.resetAllDatasets();

        let data = authoring_data["data"] as JSON;
        let type = data["type"].stringValue;
        var resultJSON:JSON = [:]
        resultJSON["type"] = JSON("authoring_response");
        resultJSON["authoring_type"] = JSON(type);
        switch(type){
        case "set_behavior_active":
            let behaviorId = data["behaviorId"].stringValue;
            let behavior = BehaviorManager.behaviors[behaviorId]!;
            let active_status = data["active_status"].boolValue;
            behavior.setActiveStatus(status:active_status);
            if(active_status){
            behavior.setAutoSpawnNum(num: 1)
            }
            else{
                behavior.setAutoSpawnNum(num: 0)
  
            }
            BehaviorManager.behaviors[behaviorId]!.createBehavior(canvas:canvas)
            resultJSON["result"] = "success";
            return resultJSON;
            
            
        case "refresh_behavior":
            let behaviorId = data["behaviorId"].stringValue;
            BehaviorManager.behaviors[behaviorId]!.createBehavior(canvas:canvas)
            resultJSON["result"] = "success";
            return resultJSON;
            
        case "request_behavior_json":
            let behaviorId = data["behaviorId"].stringValue;
            let behavior = BehaviorManager.behaviors[behaviorId]!;
            let behaviorJSON:JSON = behavior.toJSON();
            resultJSON["result"] = "success";
            resultJSON["data"] = behaviorJSON
            return resultJSON;
            
        case "behavior_added":
            let name = data["name"].stringValue;
            let id = data["id"].stringValue;
            let data = data["data"]
            //let behavior = BehaviorDefinition(id:data["id"].stringValue, name: data["name"].stringValue);
            let behavior = BehaviorDefinition(id:id,name:name);
            behavior.parseJSON(json: data)

            
            if(BehaviorManager.behaviors[id] != nil){
                throw BehaviorError.duplicateName;
            }
            else{
                BehaviorManager.behaviors[id] = behavior;

               behavior.createBehavior(canvas:canvas)

                resultJSON["result"] = "success";
                return resultJSON;
            }
            
            //request to check dependency
        case "delete_behavior_request":
            let behaviorId = data["behaviorId"].stringValue;
            let behavior = BehaviorManager.behaviors[behaviorId]!;
            let dependents = self.checkDependency(behaviorId:behavior.id);
            if(dependents.count == 0){
                resultJSON["result"] = "success";
            }
            else{
                resultJSON["result"] = "check";
                resultJSON["data"] = ["dependents":JSON(dependents)]
            }
            return resultJSON;
            
        //hard delete despite any dependencies
        case "hard_delete_behavior":
            
            let behaviorId = data["behaviorId"].stringValue;
            let behavior = BehaviorManager.behaviors[behaviorId]!;
            BehaviorManager.behaviors.removeValue(forKey: behaviorId)
            behavior.clearBehavior();
            resultJSON["result"] = "success"
            return resultJSON
            
        case "state_added":
           
            BehaviorManager.behaviors[data["behaviorId"].stringValue]!.parseStateJSON(data:data);
            BehaviorManager.behaviors[data["behaviorId"].stringValue]!.createBehavior(canvas:canvas)
            
            
            resultJSON["result"] = "success";
            return resultJSON;
            
        case "state_moved":
             let behaviorId = data["behaviorId"].stringValue;
              let stateId = data["stateId"].stringValue;
             let x  = data["x"].floatValue
             let y = data["y"].floatValue

             BehaviorManager.behaviors[behaviorId]!.setStatePosition(stateId:stateId,x:x,y:y);
            resultJSON["result"] = "success";
            return resultJSON;
        case "state_removed":
            
            BehaviorManager.behaviors[data["behaviorId"].stringValue]!.removeState(stateId: data["stateId"].stringValue);
            
            BehaviorManager.behaviors[data["behaviorId"].stringValue]!.createBehavior(canvas:canvas)
            
            resultJSON["result"] = "success";
            return resultJSON;
            
        case "transition_added","transition_event_added", "transition_event_condition_changed":
            BehaviorManager.behaviors[data["behaviorId"].stringValue]!.parseTransitionJSON(data:data)
            BehaviorManager.behaviors[data["behaviorId"].stringValue]!.createBehavior(canvas:canvas)
            
            resultJSON["result"] = "success";
            return resultJSON;
            
        case "transition_removed":
            do{
                try BehaviorManager.behaviors[data["behaviorId"].stringValue]!.removeTransition(id: data["transitionId"].stringValue);
                BehaviorManager.behaviors[data["behaviorId"].stringValue]!.createBehavior(canvas:canvas)
                
                resultJSON["result"] = "success";
                return resultJSON;            }
            catch{
                print("transition id does not exist, cannot remove");
                resultJSON["result"] = "failure";
                return resultJSON;
            }
        case "transition_event_removed" :
            do{
                try BehaviorManager.behaviors[data["behaviorId"].stringValue]!.setTransitionToDefaultEvent(transitionId: data["transitionId"].stringValue)
                BehaviorManager.behaviors[data["behaviorId"].stringValue]!.createBehavior(canvas:canvas);
                resultJSON["result"] = "success";
                return resultJSON;            }
            catch{
                resultJSON["result"] = "failure";
                return resultJSON;            }
            
   
            
        case "method_added","method_argument_changed":
            let behaviorId = data["behaviorId"].stringValue
            let methodJSON = BehaviorManager.behaviors[behaviorId]!.parseMethodJSON(data: data)
            BehaviorManager.behaviors[behaviorId]!.createBehavior(canvas:canvas);
            let targetMethod = data["targetMethod"].stringValue
            if(targetMethod == "spawn"){
            var behavior_list =  methodJSON["argumentList"]
            for (key,value) in BehaviorManager.behaviors{
                if key != behaviorId {
                    behavior_list[key] = JSON(value.name);
                }
            }
            }
            resultJSON["result"] = "success";
            resultJSON["data"] = methodJSON;
            return resultJSON;
         
            
        case "method_removed":
            BehaviorManager.behaviors[data["behaviorId"].stringValue]!.removeMethod(methodId: data["methodId"].stringValue)
            BehaviorManager.behaviors[data["behaviorId"].stringValue]!.createBehavior(canvas:canvas);
            resultJSON["result"] = "success";
            return resultJSON;
            
        case "mapping_added":
            let behaviorId = data["behaviorId"].stringValue;
            
            BehaviorManager.behaviors[behaviorId]!.parseMappingJSON(data:data)
            BehaviorManager.behaviors[behaviorId]!.createBehavior(canvas:canvas)
            
            resultJSON["result"] = "success";
            return resultJSON;
            
       /* case "mapping_updated":
            let behaviorId = data["behaviorId"].stringValue;
            
            
            BehaviorManager.behaviors[behaviorId]!.parseMappingJSON(data: data)
            BehaviorManager.behaviors[behaviorId]!.createBehavior(canvas:canvas)
            
            
            resultJSON["result"] = "success";
            return resultJSON;*/
            
        case "expression_modified":
            let behaviorId = data["behaviorId"].stringValue;
            let generatorId = data["generatorId"];
            print("generatorId",generatorId,generatorId == JSON.null)
            if(generatorId != JSON.null){
            BehaviorManager.behaviors[data["behaviorId"].stringValue]!.parseGeneratorJSON(data:data)
            }
            BehaviorManager.behaviors[data["behaviorId"].stringValue]!.parseExpressionJSON(data:data)
            
            BehaviorManager.behaviors[behaviorId]!.createBehavior(canvas:canvas)
            
            resultJSON["result"] = "success";
            return resultJSON;
            
            
        case "mapping_removed":
            
            do{
                try BehaviorManager.behaviors[data["behaviorId"].stringValue]!.removeMapping(id: data["mappingId"].stringValue);
                BehaviorManager.behaviors[data["behaviorId"].stringValue]!.createBehavior(canvas:canvas)
                resultJSON["result"] = "success";
                return resultJSON;
            }
            catch{
                resultJSON["result"] = "failure";
                return resultJSON;
            }
            
        case "dataset_loaded":
             #if DEBUG
                //print("dataset loaded",data);
            #endif
           BehaviorManager.parseDataset(data:data)
            
            resultJSON["result"] = "success";
            return resultJSON;
            
        default:
            break
        }
        
        
        
        resultJSON["result"] = "failure";
        return resultJSON;
    }
    
    
   static func parseDataset(data:JSON){
    let id = data["id"].stringValue;
    let table = Table(id:id);
        table.loadDataFromJSON(data: data["dataset"]);
    BehaviorManager.datasets[id] = table;
    }
    
    static func resetAllDatasets(){
        print("resetting all datasets")
        for (_,value) in BehaviorManager.datasets{
            value.resetColumns();
        }
    }
    
    //checks to see if other behaviors reference the target behavior
    func checkDependency(behaviorId:String)->[String:String]{
        var dependentBehaviors = [String:String]()
        
        for (_,value) in BehaviorManager.behaviors {
            if(value.id != behaviorId){
                let dependent = value.checkDependency(behaviorId: behaviorId);
                if(dependent){
                    dependentBehaviors[value.id] = value.name;
                }
            }
        }
        
        return dependentBehaviors;
        
    }
    
    func getAllBehaviorJSON()->JSON {
        var behaviorJSON = [JSON]()
        for (_, behavior) in BehaviorManager.behaviors {
            let data:JSON = behavior.toJSON();
            
            behaviorJSON.append(data);
        }
       
        return JSON(behaviorJSON);
        
    }
    
    func getBehaviorJSON(name:String) throws->String{
        if(BehaviorManager.behaviors[name] != nil){
            var behaviorJSON:JSON = BehaviorManager.behaviors[name]!.toJSON();
            return behaviorJSON.stringValue;
        }
        else{
            throw BehaviorError.behaviorDoesNotExist;
        }
        
    }
    
    func defaultSetup(name:String) throws->BehaviorDefinition {
        let b = BehaviorDefinition(id:NSUUID().uuidString,name: name)
        //TODO: add check for if name is a duplicate
        if(BehaviorManager.behaviors[name] != nil){
            throw BehaviorError.duplicateName;
        }
        else{
            
            BehaviorManager.behaviors[name] = b;
            
            b.addState(stateId: NSUUID().uuidString,stateName:"start", stateX: 20.0, stateY:150.0)
            
            b.addState(stateId: NSUUID().uuidString,stateName:"default", stateX: 1000.0, stateY: 150.0)
            
            b.addTransition(transitionId: NSUUID().uuidString, name: "setup", eventEmitter: nil, parentFlag: false, event: "STATE_COMPLETE", fromStateId: "start", toStateId:"default", condition: nil, displayName: "state complete")
            return b;
        }
        
        
    }
    
    
    
    
    
    
    
}

