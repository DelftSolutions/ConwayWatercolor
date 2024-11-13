//
//  Preferences.swift
//  ScreenSaverMinimal
//
//  Created by Guillaume Louel on 23/06/2020.
//
//  Includes a couple of convenience helpers using the new Swift 5 property wrappers

import Foundation
import ScreenSaver
import OSLog

struct Preferences {
    static var canvasColor1: Color = Color(red: 1, green: 0.933, blue: 0)
    static var canvasColor2: Color = Color(red: 1, green: 0.157, blue: 0.2228)
    static var canvasColor3: Color = Color(red: 0, green: 0.663, blue: 0.971)
    static var backgroundColor: Color = Color(red: 0.828, green: 0.793, blue: 0.737)
    static var isInverted: Bool = false
    
    static var renderScale: Float = 21.0
    static var spawnProbability: Float = 0.0004487479745876044
    static var simSpeed: Float = 7
    static var trailScale: Float = 1.57
    
    static var noiseSpeed: Float = 0.1
    static var activityMultiplier: Float = -0.0073
    static var lifeStateMultiplier: Float = 0.8266
    static var idleThreshold: Float = 0.299
    static var bleachBackground: Bool = false
    static var invertBackground: Bool = false
    static var logo: String = "logo-max-white"
    
    static func toDict() -> [String: Any] {
        return [
            "v": 1,
            "Color1": [canvasColor1.red, canvasColor1.green, canvasColor1.blue],
            "Color2": [canvasColor2.red, canvasColor2.green, canvasColor2.blue],
            "Color3": [canvasColor3.red, canvasColor3.green, canvasColor3.blue],
            "BackgroundColor": [backgroundColor.red, backgroundColor.green, backgroundColor.blue],
            "IsInverted": isInverted,
            "RenderScale": renderScale,
            "SpawnProbability": spawnProbability,
            "SimSpeed": simSpeed,
            "TrailScale": trailScale,
            "NoiseSpeed": noiseSpeed,
            "ActivityMultiplier": activityMultiplier,
            "LifeStateMultiplier": lifeStateMultiplier,
            "IdleThreshold": idleThreshold,
            "BleachBackground": bleachBackground,
            "InvertBackground": invertBackground,
            "Logo": logo,
        ]
    }
    
    static func loadDict(_ dict: [String: Any]) {
        if dict["Color1"] != nil {
            let arr = dict["Color1"] as! [Double]
            canvasColor1.red = Float(arr[0])
            canvasColor1.green = Float(arr[1])
            canvasColor1.blue = Float(arr[2])
        }
        if dict["Color2"] != nil {
            let arr = dict["Color2"] as! [Double]
            canvasColor2.red = Float(arr[0])
            canvasColor2.green = Float(arr[1])
            canvasColor2.blue = Float(arr[2])
        }
        if dict["Color3"] != nil {
            let arr = dict["Color3"] as! [Double]
            canvasColor3.red = Float(arr[0])
            canvasColor3.green = Float(arr[1])
            canvasColor3.blue = Float(arr[2])
        }
        if dict["BackgroundColor"] != nil {
            let arr = dict["BackgroundColor"] as! [Double]
            backgroundColor.red = Float(arr[0])
            backgroundColor.green = Float(arr[1])
            backgroundColor.blue = Float(arr[2])
        }
        if dict["RenderScale"] != nil {
            renderScale = Float(dict["RenderScale"] as! Double)
        }
        if dict["IsInverted"] != nil {
            isInverted = dict["IsInverted"] as! Bool
        }
        if dict["SpawnProbability"] != nil {
            spawnProbability = Float(dict["SpawnProbability"] as! Double)
        }
        if dict["SimSpeed"] != nil {
            simSpeed = Float(dict["SimSpeed"] as! Double)
        }
        if dict["TrailScale"] != nil {
            trailScale = Float(dict["TrailScale"] as! Double)
        }
        if dict["NoiseSpeed"] != nil {
            noiseSpeed = Float(dict["NoiseSpeed"] as! Double)
        }
        if dict["ActivityMultiplier"] != nil {
            activityMultiplier = Float(dict["ActivityMultiplier"] as! Double)
        }
        if dict["LifeStateMultiplier"] != nil {
            lifeStateMultiplier = Float(dict["LifeStateMultiplier"] as! Double)
        }
        if dict["IdleThreshold"] != nil {
            idleThreshold = Float(dict["IdleThreshold"] as! Double)
        }
        if dict["BleachBackground"] != nil {
            bleachBackground = dict["BleachBackground"] as! Bool
        } else {
            bleachBackground = false;
        }
        if dict["InvertBackground"] != nil {
            invertBackground = dict["InvertBackground"] as! Bool
        } else {
            invertBackground = false;
        }
        if dict["Logo"] != nil {
            logo = dict["Logo"] as! String
        } else {
            logo = "logo-max-white";
        }
    }
    
    static func LoadFromUserprefs() {
        let module = Bundle.main.bundleIdentifier!
        
        var prefData: Data? = nil
        if let userDefaults = ScreenSaverDefaults(forModuleWithName: module) {
            prefData = userDefaults.object(forKey: "current") as? Data
        }
        
        if prefData == nil {
            loadDict([:])
        } else {
            do {
                let dict = try JSONSerialization.jsonObject(with: prefData!) as? [String: Any]
                
                if dict == nil {
                    loadDict([:])
                } else {
                    Preferences.loadDict(dict!)
                }
            } catch {
                print("Error loading userPrefs, resetting")
                loadDict([:])
            }
        }
    }
    
    static func saveToUserprefs() -> Bool {
        do {
            let module = Bundle.main.bundleIdentifier!
            
            let json = try JSONSerialization.data(withJSONObject: Preferences.toDict())
            if let userDefaults = ScreenSaverDefaults(forModuleWithName: module) {
                userDefaults.set(json, forKey: "current")
                
                userDefaults.synchronize()
            } else {
                print("Failed to load userDefaults to save");
                return false;
            }
            
        } catch {
            print("Failed to save userPrefs!")
            return false
        }
        return true
    }
}

// MARK: - Helpers

struct Color {
    var red: Float
    var green: Float
    var blue: Float
    
    func toFloat3() -> simd_float3 {
        return simd_float3(Float(red), Float(green), Float(blue));
    }
    
    var nsColor: NSColor {
        return NSColor(red: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: 1.0)
    }
    
    static func from(nsColor: NSColor) -> Color {
        let converted = nsColor.usingColorSpace(.genericRGB)!
        return Color(red: Float(converted.redComponent), green: Float(converted.greenComponent), blue: Float(converted.blueComponent))
    }
}
