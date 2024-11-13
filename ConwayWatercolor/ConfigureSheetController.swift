//
//  ConfigureSheetController.swift
//  ScreenSaverMinimal
//
//  Created by Mirko Fetter on 28.10.16.
//
//  Based on https://github.com/erikdoe/swift-circle
//
//  Updated for Swift 5 / Catalina / Big Sur by Guillaume Louel 23/06/20


import Cocoa

class ConfigureSheetController : NSObject {
    
    @IBOutlet var window: NSWindow?
    @IBOutlet var canvasColorWell1: NSColorWell!
    @IBOutlet var canvasColorWell2: NSColorWell!
    @IBOutlet var canvasColorWell3: NSColorWell!
    @IBOutlet var canvasColorBackground: NSColorWell!
    
    @IBOutlet var renderScaleSlider: NSSlider!
    @IBOutlet var spawnProbabilitySlider: NSSlider!
    @IBOutlet var simSpeedSlider: NSSlider!
    @IBOutlet var trailScaleSlider: NSSlider!
    
    @IBOutlet var noiseSpeedSlider: NSSlider!
    @IBOutlet var activityMultiplierSlider: NSSlider!
    @IBOutlet var lifeStateMultiplierSlider: NSSlider!
    @IBOutlet var idleThresholdSlider: NSSlider!
    
    @IBOutlet var bleachBackgroundSwitch: NSSwitch!
    @IBOutlet var invertedBackgroundSwitch: NSSwitch!
    
    @IBOutlet var logoSelectButton: NSPopUpButton!

    @IBOutlet weak var helpLabel: NSTextField!

    override init() {
        super.init()
        let myBundle = Bundle(for: ConfigureSheetController.self)
        myBundle.loadNibNamed("ConfigureSheet", owner: self, topLevelObjects: nil)
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        
        Preferences.LoadFromUserprefs()
        
        reloadSliders()
    }
    func reloadSliders() {
        
        // Do your UI init here!
        canvasColorWell1.color = Preferences.canvasColor1.nsColor
        canvasColorWell2.color = Preferences.canvasColor2.nsColor
        canvasColorWell3.color = Preferences.canvasColor3.nsColor
        canvasColorBackground.color = Preferences.backgroundColor.nsColor
        
        renderScaleSlider.doubleValue = Double(Preferences.renderScale)
        spawnProbabilitySlider.doubleValue = Double(Preferences.spawnProbability) * 1000.0
        simSpeedSlider.doubleValue = Double(50 - Preferences.simSpeed)
        trailScaleSlider.doubleValue = Double(Preferences.trailScale)
        
        noiseSpeedSlider.doubleValue = pow(Double(Preferences.noiseSpeed), 1.0/3.0)
        activityMultiplierSlider.doubleValue = Double(Preferences.activityMultiplier)
        lifeStateMultiplierSlider.doubleValue = Double(Preferences.lifeStateMultiplier)
        idleThresholdSlider.doubleValue = Double(Preferences.idleThreshold)
        
        bleachBackgroundSwitch.state = Preferences.bleachBackground ? .on : .off
        invertedBackgroundSwitch.state = Preferences.invertBackground ? .on : .off
        
        var found = false
        for item in logoSelectButton.itemArray {
            if item.identifier?.rawValue == Preferences.logo {
                logoSelectButton.select(item)
                found = true
            }
        }
        if !found
        {
            logoSelectButton.selectItem(at: 0)
        }
        
        if helpLabel != nil {
            let underLineStyle = [NSAttributedString.Key.underlineStyle: NSUnderlineStyle.single.rawValue]
            let attributedString = NSMutableAttributedString(string: "Help", attributes: underLineStyle)
            helpLabel.attributedStringValue = attributedString
        }
    }
    
    @IBAction func onClickPreset(_ sender: NSPopUpButton!) {
        let selectedItem = sender.selectedItem!.identifier!.rawValue
        
        let db = [
            "neon": #"{"v":1,"ActivityMultiplier":0.30069553852081299,"Color2":[0.13525280356407166,1,0.024886835366487503],"IdleThreshold":0.28201344609260559,"Logo":"logo-ds-white","SpawnProbability":0.00025327006005682051,"TrailScale":0.31898921728134155,"BackgroundColor":[0.01004718616604805,0.038772746920585632,0.031161896884441376],"SimSpeed":5.3623771667480469,"Color3":[0,0,0.9981992244720459],"IsInverted":false,"BleachBackground":true,"Color1":[0.9859541654586792,0,0.026940008625388145],"LifeStateMultiplier":-0.7426038384437561,"InvertBackground":true,"NoiseSpeed":0.42516869306564331,"RenderScale":17}"#,
            "matrix": #"{"TrailScale":1.9669622182846069,"v":1,"InvertBackground":true,"SimSpeed":3.8188362121582031,"IdleThreshold":0.114566370844841,"Color1":[0.69249600172042847,1,0.84084510803222656],"Color2":[0.37886357307434082,1,0.54875057935714722],"Logo":"logo-ds-white","BackgroundColor":[0.019857162609696388,0.019857164472341537,0.019857168197631836],"ActivityMultiplier":1,"RenderScale":8,"NoiseSpeed":0.19462895393371582,"BleachBackground":false,"SpawnProbability":0.00028388385544531047,"LifeStateMultiplier":-0.0079104620963335037,"Color3":[0.4814445972442627,0.63014680147171021,0.54987359046936035],"IsInverted":false}"#,
            "gameoflife": #"{"Color1":[0.99897301197052002,0.93125414848327637,0.039746273308992386],"ActivityMultiplier":-0.0072981975972652435,"LifeStateMultiplier":0.82658207416534424,"BleachBackground":false,"BackgroundColor":[0.78751087188720703,0.74848926067352295,0.68269526958465576],"SpawnProbability":0.0004487479745876044,"InvertBackground":false,"NoiseSpeed":0,"RenderScale":21,"TrailScale":1.5760922431945801,"Logo":"logo-ds-black","v":1,"IsInverted":false,"Color3":[0.072327166795730591,0.59053975343704224,0.96232986450195312],"Color2":[0.98623359203338623,0.019132889807224274,0.1724221408367157],"SimSpeed":6.5525741577148438,"IdleThreshold":0.29941979050636292}"#,
            "oil": #"{"Color3":[0.78327417373657227,0.70900106430053711,0.96309268474578857],"IsInverted":false,"NoiseSpeed":0.42516869306564331,"SpawnProbability":0.00032746334909461439,"SimSpeed":8.6353569030761719,"BackgroundColor":[0,0,0],"Color1":[0.99809360504150391,0.91447460651397705,0.80034911632537842],"LifeStateMultiplier":-0.010139106772840023,"InvertBackground":true,"RenderScale":21,"Color2":[0.99818575382232666,0.92595911026000977,0.96239590644836426],"BleachBackground":false,"TrailScale":10,"ActivityMultiplier":0,"Logo":"logo-ds-white","IdleThreshold":0.72352147102355957,"v":1}"#,
            "ink": #"{"v":1,"SimSpeed":4.2910232543945312,"Color1":[0.0092786252498626709,0.12652374804019928,0.15969750285148621],"ActivityMultiplier":0,"BleachBackground":false,"IsInverted":false,"NoiseSpeed":0.26983422040939331,"SpawnProbability":9.4704293587710708e-05,"RenderScale":21,"Color3":[0.81927406787872314,0.10842597484588623,0.14145712554454803],"InvertBackground":false,"TrailScale":1.849170446395874,"Logo":"logo-max-color","LifeStateMultiplier":0,"BackgroundColor":[0.98943054676055908,0.95796835422515869,0.8640669584274292],"Color2":[0.91610729694366455,0.89003515243530273,0.79781758785247803],"IdleThreshold":1}"#,
            "muted": #"{"ActivityMultiplier":0,"SpawnProbability":4.8618181608617306e-05,"InvertBackground":false,"v":1,"Color2":[0.13525280356407166,1,0.024886835366487503],"BackgroundColor":[0.20868071913719177,1,0.63409161567687988],"IsInverted":false,"SimSpeed":1,"NoiseSpeed":0.42516869306564331,"RenderScale":2,"TrailScale":2.8426556587219238,"LifeStateMultiplier":-0.010139106772840023,"Logo":"logo-ds-orange","Color3":[0,0,0.9981992244720459],"Color1":[0.9859541654586792,0,0.026940008625388145],"IdleThreshold":0.06923096626996994,"BleachBackground":true}"#,
            "retro": #"{"Color1":[0.7373620867729187,1,0.87136399745941162],"BackgroundColor":[0.011311651207506657,0.0099806208163499832,0.010512500070035458],"BleachBackground":true,"NoiseSpeed":0.19462895393371582,"IsInverted":false,"Logo":"logo-max-white","Color3":[0.55063050985336304,0.68662387132644653,0.61866706609725952],"SimSpeed":3.8188362121582031,"IdleThreshold":0.114566370844841,"Color2":[0.42561632394790649,1,0.61705249547958374],"LifeStateMultiplier":-0.0079104620963335037,"SpawnProbability":0.00028388385544531047,"TrailScale":1.9669622182846069,"ActivityMultiplier":1,"v":1,"InvertBackground":true,"RenderScale":8}"#,
            "cherryblossom": #"{"Color1":[0,1,0],"Color3":[0.72297602891921997,0.71629601716995239,0.72791683673858643],"Color2":[0.90180248022079468,0.7588571310043335,1],"NoiseSpeed":1,"ActivityMultiplier":1,"SpawnProbability":0.0006694694166071713,"IsInverted":false,"RenderScale":6,"SimSpeed":29.48809814453125,"IdleThreshold":0.11924944818019867,"BackgroundColor":[0,0.20783211290836334,0.60615009069442749],"InvertBackground":true,"TrailScale":3.9173617362976074,"BleachBackground":true,"Logo":"logo-ds-black","v":1,"LifeStateMultiplier":0.24904833734035492}"#,
            "blots": #"{"TrailScale":1.7793483734130859,"BackgroundColor":[0.85789632797241211,0.8434033989906311,0.92296361923217773],"BleachBackground":true,"v":1,"ActivityMultiplier":0.017085693776607513,"SimSpeed":1,"LifeStateMultiplier":-0.1537269800901413,"Logo":"logo-max-white","InvertBackground":false,"Color3":[0.45093908905982971,0.45093908905982971,0.45093908905982971],"IdleThreshold":0.70547330379486084,"IsInverted":false,"Color2":[0.65203070640563965,0.65203070640563965,0.65203070640563965],"NoiseSpeed":1,"RenderScale":6,"Color1":[0.99999505281448364,1,1],"SpawnProbability":0.00048544033779762685}"#,
            "microscopic": #"{"InvertBackground":true,"LifeStateMultiplier":0.24904833734035492,"BackgroundColor":[0,0,0],"Color1":[0,1,0],"TrailScale":1.0058879852294922,"SimSpeed":29.48809814453125,"BleachBackground":false,"Color2":[0.90180248022079468,0.7588571310043335,1],"Color3":[0.72297602891921997,0.71629601716995239,0.72791683673858643],"RenderScale":6,"SpawnProbability":0.0006694694166071713,"ActivityMultiplier":1,"IdleThreshold":0.11924944818019867,"NoiseSpeed":1,"v":1,"IsInverted":false,"Logo":"logo-max-color"}"#,
            "radar": #"{"Color2":[0.48859408497810364,0.17009060084819794,1],"SimSpeed":5.37091064453125,"ActivityMultiplier":0.91246902942657471,"BackgroundColor":[0.019857162609696388,0.019857164472341537,0.019857168197631836],"InvertBackground":false,"Color1":[0.11973889172077179,0.93520808219909668,1],"IsInverted":false,"Color3":[0.64864599704742432,0.45325437188148499,0.014000219292938709],"v":1,"SpawnProbability":0.00078987580491229892,"Logo":"logo-ds-white","BleachBackground":false,"RenderScale":23,"TrailScale":7.3011364936828613,"NoiseSpeed":0.041120424866676331,"LifeStateMultiplier":-0.33945643901824951,"IdleThreshold":0.56359970569610596}"#,
            "grass": #"{"IdleThreshold":0.24233642220497131,"Logo":"logo-ds-white","SimSpeed":1,"TrailScale":0,"Color1":[0,1.1785851711465511e-05,0.50196588039398193],"Color3":[0,0,0],"RenderScale":4,"ActivityMultiplier":0,"BleachBackground":false,"Color2":[0.79999417066574097,1,0.40000131726264954],"SpawnProbability":0.0010000000474974513,"IsInverted":false,"LifeStateMultiplier":0.082772664725780487,"BackgroundColor":[0.16541001200675964,0.037813693284988403,0.16754055023193359],"v":1,"InvertBackground":true,"NoiseSpeed":0.00069782213540747762}"#,
            "lichen": #"{"BackgroundColor":[0.13130249083042145,0.99969744682312012,0.023593783378601074],"SimSpeed":7.0104928016662598,"SpawnProbability":0.000675792689435184,"TrailScale":7.0140671730041504,"RenderScale":8,"Color1":[0.99999505281448364,1,1],"NoiseSpeed":0.39779803156852722,"ActivityMultiplier":0,"LifeStateMultiplier":-0.16753718256950378,"IsInverted":false,"IdleThreshold":0.42160007357597351,"v":1,"InvertBackground":true,"Color2":[0,0,0],"BleachBackground":false,"Logo":"logo-max-white","Color3":[0.99999690055847168,1,0.4000009298324585]}"#,
            "rgb": #"{"BackgroundColor":[0.99999505281448364,1,1],"SimSpeed":4.3336119651794434,"IdleThreshold":0.78508752584457397,"Color2":[0.13130249083042145,0.99969744682312012,0.023593783378601074],"IsInverted":false,"LifeStateMultiplier":0.082772664725780487,"BleachBackground":false,"NoiseSpeed":0.58014476299285889,"Color3":[6.5747648477554321e-05,0.0018010139465332031,0.99822854995727539],"v":1,"InvertBackground":false,"RenderScale":13,"SpawnProbability":0.00026733183767646551,"Color1":[0.98625171184539795,0.0072359740734100342,0.027423009276390076],"TrailScale":3.8168988227844238,"ActivityMultiplier":0,"Logo":"logo-ds-black"}"#,
            
        ]
        
        if db[selectedItem] != nil {
            do {
                let data = db[selectedItem]!.data(using: .utf8)!
                
                let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]
                
                Preferences.loadDict(dict)
                Preferences.saveToUserprefs()
                reloadSliders()
                
            } catch {
                print("Error during paste")
            }
        } else {
            print("Missing preset \(selectedItem)")
        }
    }
    
    @IBAction func onClickHelp(_ sender: AnyObject) {
        NSWorkspace.shared.open(URL.init(string: "https://github.com/DelftSolutions/ConwayWatercolor/issues/new")!)
    }
    @IBAction func onClickCopy(_ sender: AnyObject) {
        do {
            let result = try JSONSerialization.data(withJSONObject: Preferences.toDict())
            
            let string = String.init(data: result, encoding: .utf8)
            
            NSPasteboard.general.clearContents()
            let outcome = NSPasteboard.general.setString(string!, forType: .string)
            print("copy: \(outcome)")
        } catch {
            print("Error during copy")
        }
    }
    @IBAction func onClickPaste(_ sender: AnyObject) {
        do {
            let data = NSPasteboard.general.string(forType: .string)!.data(using: .utf8)!
            
            let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            
            Preferences.loadDict(dict)
            Preferences.saveToUserprefs()
            reloadSliders()
            
        } catch {
            print("Error during paste")
        }
    }

    @IBAction func updateDefaults(_ sender: AnyObject) {
        Preferences.canvasColor1 = Color.from(nsColor: canvasColorWell1!.color)
        Preferences.canvasColor2 = Color.from(nsColor: canvasColorWell2!.color)
        Preferences.canvasColor3 = Color.from(nsColor: canvasColorWell3!.color)
        Preferences.backgroundColor = Color.from(nsColor: canvasColorBackground!.color)
        
        Preferences.renderScale = Float(renderScaleSlider!.doubleValue)
        Preferences.spawnProbability = Float(spawnProbabilitySlider!.doubleValue / 1000.0)
        Preferences.simSpeed = Float(50.0 - simSpeedSlider!.doubleValue)
        Preferences.trailScale = Float(trailScaleSlider!.doubleValue)
        
        Preferences.noiseSpeed = Float(pow(noiseSpeedSlider.doubleValue, 3.0))
        Preferences.activityMultiplier = Float(activityMultiplierSlider.doubleValue)
        Preferences.lifeStateMultiplier = Float(lifeStateMultiplierSlider.doubleValue)
        Preferences.idleThreshold = Float(idleThresholdSlider.doubleValue)
        
        Preferences.bleachBackground = bleachBackgroundSwitch.state == .on
        Preferences.invertBackground = invertedBackgroundSwitch.state == .on
        
        Preferences.logo = logoSelectButton.selectedItem?.identifier?.rawValue ?? "none"
        
        Preferences.saveToUserprefs()
    }
   
    @IBAction func closeConfigureSheet(_ sender: AnyObject) {
        // Remember to close anything else first
        NSColorPanel.shared.close()

        // Now close the sheet (this works on older macOS versions too)
        window?.sheetParent?.endSheet(window!)
        
        // Remember, you are still in memory at this point until you get killed by parent.
        // If your parent is System Preferences, you will remain in memory as long as System
        // Preferences is open. Reopening the sheet will just wake you up.
        //
        // An unfortunate side effect of this is that if your user updates to a new version with
        // System Preferences open, they will see weird things (ui from old version running
        // new code, etc), so tell them not to do that!
    }
}
