import ScreenSaver
import MetalKit
import os.log

class ConwayWatercolorView : ScreenSaverView, MTKViewDelegate {
    lazy var sheetController: ConfigureSheetController = ConfigureSheetController()
    var isPreviewBug: Bool = false
    
    var metalView: MTKView
    
    var metalDevice: MTLDevice
    var metalCommandQueue: MTLCommandQueue?
    var metalLibrary: MTLLibrary?
    
    var shaderGameOfLifeFunc: MTLFunction?
    var shaderGameOfLifeState: MTLComputePipelineState?
    var shaderTrailsFunc: MTLFunction?
    var shaderTrailsState: MTLComputePipelineState?
    var shaderTrailResetState: MTLComputePipelineState?
    var shaderDisplayVertexFunc: MTLFunction?
    var shaderDisplayFragmentFunc: MTLFunction?
    var shaderDisplayState: MTLRenderPipelineState?
    var inConfig: Bool
    var initTime: Float
    var updateCounter: UInt32 = 0
    var framesLeft: Int = 0
    var updateFrames: Int = 1
    var trailScale: Int = 1
    var gameOfLifeScale: Int = 8
    
    var textureGameOfLifePrev: MTLTexture?
    var textureGameOfLifeNext: MTLTexture?
    var textureTrailPrev: MTLTexture?
    var textureTrailNext: MTLTexture?
    
    var random1Lifetime: Int = 0
    var random1RefreshRate: Int = 1
    var textureRandom1Prev: MTLTexture?
    var textureRandom1Next: MTLTexture?
    var random2Lifetime: Int = 0
    var random2RefreshRate: Int = 4
    var textureRandom2Prev: MTLTexture?
    var textureRandom2Next: MTLTexture?
    var random3Lifetime: Int = 0
    var random3RefreshRate: Int = 16
    var textureRandom3Prev: MTLTexture?
    var textureRandom3Next: MTLTexture?
    
    var textureLogo: MTLTexture?
    var currentLogo: String = "none"
    var logoBorder: Float = 20
    var logoBlend: Float = 0.0
    var logoSize: simd_float2 = [0, 0]
    
    override init(frame: NSRect, isPreview: Bool) {
        // Radar# FB7486243, legacyScreenSaver.appex always returns true, unlike what used
        // to happen in previous macOS versions, see documentation here : https://developer.apple.com/documentation/screensaver/screensaverview/1512475-init$

        var preview = true

        // We can workaround that bug by looking at the size of the frame
        // It's always 296.0 x 184.0 when running in preview mode
        if frame.width > 400 && frame.height > 300 {
            if isPreview {
                isPreviewBug = true
            }
            preview = false
        }
        inConfig = preview
        
        metalDevice = MTLCreateSystemDefaultDevice()!
        metalView = MTKView.init(frame: frame)
        metalView.device = metalDevice
        initTime = Float(Int64(Date().timeIntervalSince1970) % 10000);
        
        super.init(frame: frame, isPreview: preview)!
        
        commonInit()
        
        metalView.delegate = self
        addSubview(metalView)
    }
    
    required init?(coder aDecoder: NSCoder) {
        metalDevice = MTLCreateSystemDefaultDevice()!
        metalView = MTKView.init(frame: NSRect(x: 0, y: 0, width: 0, height: 0))
        metalView.device = metalDevice
        initTime = Float(Date().timeIntervalSince1970)
        inConfig = true
        
        super.init(coder: aDecoder)
        
        metalView.frame = bounds
        commonInit()
        
        metalView.delegate = self
        addSubview(metalView)
    }
    
    func commonInit() {
        debugLog("Conway commonInit")
#if NO_SCREENSAVER_EXIT
        print("No exit on screensaver end")
#endif
        
        Preferences.LoadFromUserprefs()
        
        metalCommandQueue = metalDevice.makeCommandQueue()
        
        var bundle = Bundle.init(identifier: "nl.maxmaton.ConwayWatercolor")
        if bundle == nil
        {
            bundle = Bundle.init(identifier: "nl.maxmaton.SaverTest")
        }
        
        do {
            try metalLibrary = metalDevice.makeDefaultLibrary(bundle: bundle!)
        } catch { fatalError("Unable to load bundle library") }
        
        metalView.autoresizingMask = [.width, .height]
        
        metalView.colorPixelFormat = .bgra10_xr
        metalView.sampleCount = 1
        metalView.preferredFramesPerSecond = 25
        metalView.autoResizeDrawable = true
        
        metalView.clearColor = MTLClearColor(red: 0.3, green: 0.2, blue: 0.1, alpha: 1.0)
        
        
        shaderGameOfLifeFunc = metalLibrary!.makeFunction(name: "updateGameOfLife")
        do    { try shaderGameOfLifeState = metalDevice.makeComputePipelineState(function: shaderGameOfLifeFunc!)}
        catch { fatalError("updateGameOfLife computePipelineState failed")}
        
        let shaderTrailResetFunc = metalLibrary!.makeFunction(name: "resetTrails")
        do    { try shaderTrailResetState = metalDevice.makeComputePipelineState(function: shaderTrailResetFunc!)}
        catch { fatalError("shaderTrailResetFunc shaderTrailResetState failed")}
        
        shaderTrailsFunc = metalLibrary!.makeFunction(name: "updateTrails")
        do    { try shaderTrailsState = metalDevice.makeComputePipelineState(function: shaderTrailsFunc!)}
        catch { fatalError("updateTrails computePipelineState failed")}
        
        shaderDisplayVertexFunc = metalLibrary!.makeFunction(name: "renderScreensaverVertex")
        shaderDisplayFragmentFunc = metalLibrary!.makeFunction(name: "renderScreensaverFragment")
        let shaderDisplayPipeline = MTLRenderPipelineDescriptor()
        shaderDisplayPipeline.vertexFunction = shaderDisplayVertexFunc
        shaderDisplayPipeline.fragmentFunction = shaderDisplayFragmentFunc
        shaderDisplayPipeline.colorAttachments[0].pixelFormat = metalView.colorPixelFormat
        do    { try shaderDisplayState = metalDevice.makeRenderPipelineState(descriptor: shaderDisplayPipeline) }
        catch { fatalError("shaderDisplay makeRenderPipelineState failed")}
        
        DistributedNotificationCenter.default.addObserver(self, selector: #selector(ConwayWatercolorView.onWillStop(_:)), name: Notification.Name("com.apple.screensaver.willstop"), object: nil)
        DistributedNotificationCenter.default.addObserver(self, selector: #selector(ConwayWatercolorView.screenIsUnlocked(_:)), name: Notification.Name("com.apple.screenIsUnlocked"), object: nil)
    }
    
    override var hasConfigureSheet: Bool {
        return true
    }
    
    override var configureSheet: NSWindow? {
        return sheetController.window
    }
    
    override func startAnimation() {
        super.startAnimation()
        debugLog("Conway startAnimation")
        metalView.preferredFramesPerSecond = 25
    }
    
    @objc func onWillStop(_ aNotification: Notification)
    {
#if !NO_SCREENSAVER_EXIT
        stopAnimation()
#endif
    }
    @objc func screenIsUnlocked(_ aNotification: Notification)
    {
#if !NO_SCREENSAVER_EXIT
        if !isPreview {
            exit(0)
        }
#endif
    }
    
    override func stopAnimation() {
        super.stopAnimation()
        
        metalView.preferredFramesPerSecond = 0
    }
    

    override func draw(_ rect: NSRect) {
        if (textureGameOfLifePrev == nil) {
            self.mtkView(metalView, drawableSizeWillChange: rect.size)
        }
    }
    
    func resetGameOfLifeTexture(texture: MTLTexture) {
        let bufferSize = texture.width * texture.height * 4;
        let fullRegion = MTLRegionMake2D(0, 0, texture.width, texture.height)
        
        let pixelPtr = UnsafeMutableRawPointer.allocate(byteCount: bufferSize, alignment: 1)
        defer { pixelPtr.deallocate() }
        texture.getBytes(pixelPtr, bytesPerRow: texture.width * 4, from: fullRegion, mipmapLevel: 0)
        var pixelData = Data.init(bytes: pixelPtr, count: bufferSize)
        
        for i in 0..<(bufferSize / 4) {
            pixelData[i*4 + 0] = 0
            pixelData[i*4 + 1] = 0
            pixelData[i*4 + 2] = 0
            pixelData[i*4 + 3] = 0
        }
        
        pixelData.withUnsafeBytes {
            texture.replace(region: fullRegion, mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: texture.width * 4)
        }
    }
    
    func resetTrailTexture(texture: MTLTexture) {
        let commandBuffer = metalCommandQueue!.makeCommandBuffer()!
        
        let commandEncoder = commandBuffer.makeComputeCommandEncoder()!
        commandEncoder.setComputePipelineState(shaderTrailResetState!)
        
        commandEncoder.setTexture(texture, index: 0)
        
        let gridSize = MTLSizeMake(texture.width, texture.height, 1)
        
        let w = shaderGameOfLifeState!.threadExecutionWidth
        let h = shaderGameOfLifeState!.maxTotalThreadsPerThreadgroup / w
        
        commandEncoder.dispatchThreads(gridSize, threadsPerThreadgroup: MTLSizeMake(w, h, 1))
        
        commandEncoder.endEncoding()
        
        commandBuffer.commit()
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        framesLeft = 0
        
        gameOfLifeScale = Int(Preferences.renderScale)
        trailScale = Int(Preferences.trailScale)
        
        let gameOfLifeDescriptor = MTLTextureDescriptor.init()
        gameOfLifeDescriptor.usage = [.shaderWrite, .shaderRead]
        gameOfLifeDescriptor.height = Int(size.height) / gameOfLifeScale * (inConfig ? 8 : 1)
        gameOfLifeDescriptor.width = Int(size.width) / gameOfLifeScale * (inConfig ? 8 : 1)
        gameOfLifeDescriptor.pixelFormat = .rgba8Uint
        
        textureGameOfLifePrev = metalDevice.makeTexture(descriptor: gameOfLifeDescriptor)
        textureGameOfLifeNext = metalDevice.makeTexture(descriptor: gameOfLifeDescriptor)
        
        resetGameOfLifeTexture(texture: textureGameOfLifeNext!)
        
        let trailTextureDescriptor = MTLTextureDescriptor.init()
        trailTextureDescriptor.usage = [.shaderWrite, .shaderRead]
        trailTextureDescriptor.height = gameOfLifeDescriptor.height
        trailTextureDescriptor.width = gameOfLifeDescriptor.width
        trailTextureDescriptor.pixelFormat = .rgba32Float
        
        textureTrailPrev = metalDevice.makeTexture(descriptor: trailTextureDescriptor)
        textureTrailNext = metalDevice.makeTexture(descriptor: trailTextureDescriptor)
        
        resetTrailTexture(texture: textureTrailNext!)
    }
    
    func updateLogo() {
        if (currentLogo == Preferences.logo) {
            return
        }
        
        var newLogoIdentifier = Preferences.logo
        let lookup = [
            "none": [
                "border": 0.0,
                "size": [Float(0.0), Float(0.0)],
                "blend": 0.0,
                "path": nil
            ],
            "logo-max-color": [
                "border": 20.0,
                "size": [Float(128), Float(128)],
                "blend": -0.8,
                "path": "logo-max-color"
            ],
            "logo-max-white": [
                "border": 20.0,
                "size": [Float(128), Float(128)],
                "blend": 0.8,
                "path": "logo-max-white"
            ],
            "logo-era-color": [
                "border": 20.0,
                "size": [Float(64), Float(64)],
                "blend": -0.5,
                "path": "logo-era-color"
            ],
            "logo-ds-black": [
                "border": 20.0,
                "size": [Float(64), Float(64)],
                "blend": -0.70,
                "path": "logo-ds-black"
            ],
            "logo-ds-orange": [
                "border": 20.0,
                "size": [Float(64), Float(64)],
                "blend": -0.5,
                "path": "logo-ds-orange"
            ],
            "logo-ds-color": [
                "border": 20.0,
                "size": [Float(64), Float(64)],
                "blend": -0.5,
                "path": "logo-ds-color"
            ],
            "logo-ds-white": [
                "border": 20.0,
                "size": [Float(64), Float(64)],
                "blend": 0.8,
                "path": "logo-ds-white"
            ],
        ]
        
        if lookup[newLogoIdentifier] == nil {
            newLogoIdentifier = "none"
        }
        do {
            
            let data = lookup[newLogoIdentifier]!
            logoSize = simd_float2(data["size"] as! [Float])
            logoBorder = Float(data["border"] as! Double)
            logoBlend = Float(data["blend"] as! Double)
            
            if data["path"] as? String != nil
            {
                let myBundle = Bundle(for: ConfigureSheetController.self)
                let textureLoader = MTKTextureLoader(device: metalDevice)
                textureLogo = try textureLoader.newTexture(name: data["path"] as! String, scaleFactor: 1.0, bundle: myBundle)
            } else {
                textureLogo = nil
            }
            
        } catch {
            print("Error loading logo")
            Preferences.logo = "none"
        }
    }
    
    func updateState() {
        if (Int(Preferences.renderScale) != gameOfLifeScale) {
            self.mtkView(metalView, drawableSizeWillChange: metalView.bounds.size)
        }
        
        if (Int(Preferences.simSpeed) != updateFrames) {
            updateFrames = Int(Preferences.simSpeed)
            framesLeft = 0
        }
        
        if (textureGameOfLifeNext == nil || textureGameOfLifePrev == nil)
        {
            debugLog("Nil textures")
            return
        }
        
        if (framesLeft > 1) {
            framesLeft -= 1
            return;
        }
        
        updateLogo()
        
        let commandBuffer = metalCommandQueue!.makeCommandBuffer()!
        
        framesLeft = updateFrames
        updateCounter += 1
        
        swap(&textureGameOfLifeNext, &textureGameOfLifePrev)
        swap(&textureTrailNext, &textureTrailPrev)
        
        var commandEncoder = commandBuffer.makeComputeCommandEncoder()!
        commandEncoder.setComputePipelineState(shaderGameOfLifeState!)
        
        commandEncoder.setTexture(textureGameOfLifePrev, index: 0)
        commandEncoder.setTexture(textureGameOfLifeNext, index: 1)
        commandEncoder.setTexture(textureTrailPrev, index: 2)
        
        var config = UpdateGameOfLifeConfig(
            size: [UInt32(textureGameOfLifeNext!.width), UInt32(textureGameOfLifeNext!.height)],
            updateCounter: updateCounter + UInt32(initTime),
            spawnProbability: Preferences.spawnProbability,
            idleThreshold: Preferences.idleThreshold
        )
        let configBuffer = metalDevice.makeBuffer(bytes: &config, length: MemoryLayout.size(ofValue: config), options: [])
        commandEncoder.setBuffer(configBuffer, offset: 0, index: 0)
        
        let gridSize = MTLSizeMake(textureGameOfLifeNext!.width, textureGameOfLifeNext!.height, 1)
        
        let w = shaderGameOfLifeState!.threadExecutionWidth
        let h = shaderGameOfLifeState!.maxTotalThreadsPerThreadgroup / w
        
        commandEncoder.dispatchThreads(gridSize, threadsPerThreadgroup: MTLSizeMake(w, h, 1))
        commandEncoder.endEncoding()
        
        commandEncoder = commandBuffer.makeComputeCommandEncoder()!
        
        commandEncoder.setComputePipelineState(shaderTrailsState!)
        
        commandEncoder.setTexture(textureGameOfLifePrev, index: 0)
        commandEncoder.setTexture(textureGameOfLifeNext, index: 1)
        commandEncoder.setTexture(textureTrailPrev, index: 2)
        commandEncoder.setTexture(textureTrailNext, index: 3)
        
        var trailConfig = UpdateTrailConfig(
            lifeSize: [UInt32(textureGameOfLifeNext!.width), UInt32(textureGameOfLifeNext!.height)],
            trailSize: [UInt32(textureTrailNext!.width), UInt32(textureTrailNext!.height)],
            lifeDecay: 0.01,
            trailDecay: 0.06,
            trailSpread: (1 - Preferences.idleThreshold),
            updateCounter: updateCounter
        )
        let trailConfigBuffer = metalDevice.makeBuffer(bytes: &trailConfig, length: MemoryLayout.size(ofValue: trailConfig), options: [])
        commandEncoder.setBuffer(trailConfigBuffer, offset: 0, index: 0)
        
        let trailGridSize = MTLSizeMake(textureTrailNext!.width, textureTrailNext!.height, 1)
        
        let trail_w = shaderGameOfLifeState!.threadExecutionWidth
        let trail_h = shaderGameOfLifeState!.maxTotalThreadsPerThreadgroup / w
        
        commandEncoder.dispatchThreads(trailGridSize, threadsPerThreadgroup: MTLSizeMake(trail_w, trail_h, 1))
        
        commandEncoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
    
    func draw(in view: MTKView) {
        let renderPassDescriptor: MTLRenderPassDescriptor? = view.currentRenderPassDescriptor
        if (renderPassDescriptor == nil)
        {
            debugLog("failed render alloc")
            return;
        }

        updateState()
        
        let commandBuffer = metalCommandQueue!.makeCommandBuffer()!
        
        let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor!)!
        
        commandEncoder.setRenderPipelineState(shaderDisplayState!)
        let vertexCoords: [SIMD2<Float>] =
        [
            [-1.0, -1.0],
            [ 1.0, -1.0],
            [-1.0,  1.0],
            [ 1.0,  1.0],
        ]
        
        let dataSize = vertexCoords.count * MemoryLayout.size(ofValue: vertexCoords[0])
        let vertexBuffer = metalDevice.makeBuffer(bytes: vertexCoords,
                                                   length:  dataSize,
                                                   options: [])
        commandEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        
        var interpolationFrac = 1.0 - max(0.0, min(1.0, Float(framesLeft) / Float(updateFrames)));
        var uniformData = RenderUniforms(
            lifeSize: [UInt32(textureGameOfLifeNext!.width), UInt32(textureGameOfLifeNext!.height)],
            trailSize: [UInt32(textureTrailNext!.width), UInt32(textureTrailNext!.height)],
            outputSize: [UInt32(metalView.bounds.width) * (inConfig ? 8 : 1), UInt32(metalView.bounds.height) * (inConfig ? 8 : 1)],
            time: Float(Date().timeIntervalSince1970) - initTime,
            interpolationFrac: interpolationFrac,
            maxOutput: Float(window!.screen!.maximumExtendedDynamicRangeColorComponentValue),
            updateCounter: updateCounter + UInt32(initTime),
            color1: Preferences.canvasColor1.toFloat3(),
            color2: Preferences.canvasColor2.toFloat3(),
            color3: Preferences.canvasColor3.toFloat3(),
            bgColor: Preferences.backgroundColor.toFloat3(),
            isInverted: Preferences.invertBackground ? 1 : 0,
            bleachBackground: Preferences.bleachBackground ? 1 : 0,
            trailSamplingNoise: Preferences.trailScale,
            activityMultiplier: Preferences.activityMultiplier,
            lifeStateMultiplier: Preferences.lifeStateMultiplier,
            noiseSpeed: Preferences.noiseSpeed,
            logoSize: logoSize,
            logoBorder: logoBorder,
            logoBlending: logoBlend
        )
        
        let uniformBuffer = metalDevice.makeBuffer(bytes: &uniformData, length: MemoryLayout.size(ofValue: uniformData), options: [])
        commandEncoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 0)
        
        commandEncoder.setFragmentTexture(textureGameOfLifePrev, index: 0)
        commandEncoder.setFragmentTexture(textureGameOfLifeNext, index: 1)
        commandEncoder.setFragmentTexture(textureTrailPrev, index: 2)
        commandEncoder.setFragmentTexture(textureTrailNext, index: 3)
        if textureLogo != nil {
            commandEncoder.setFragmentTexture(textureLogo, index: 4)
        }
        
        commandEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        
        commandEncoder.endEncoding()
        
        commandBuffer.present(metalView.currentDrawable!)
        commandBuffer.commit()
    }
    
    override func animateOneFrame() {
        //window!.disableFlushing()
        
        //window!.enableFlushing()
    }
    
    func debugLog(_ message: String) {
        print("Conway \(message)")
        
        let log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "Screensaver")
        os_log("Conway: %{public}@", log: log, type: .error, message)
    }
}
    

