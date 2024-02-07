module MainLoop
	using ..JulGame
	using ..JulGame: Component, Input, Math, UI
    import ..JulGame: deprecated_get_property, Component
    import ..JulGame.SceneManagement: SceneBuilderModule
	include("Enums.jl")
	include("Constants.jl")
	include("Scene.jl")

	export Main
	mutable struct Main
		assets::String
		autoScaleZoom::Bool
		cameraBackgroundColor::Tuple{Int64, Int64, Int64}
		close::Bool
		currentTestTime::Float64
		debugTextBoxes::Vector{UI.TextBoxModule.TextBox}
		globals::Vector{Any}
		input::Input
		isDraggingEntity::Bool
		lastMousePosition::Union{Math.Vector2, Math.Vector2f}
		lastMousePositionWorld::Union{Math.Vector2, Math.Vector2f}
		level::JulGame.SceneManagement.SceneBuilderModule.Scene
		mousePositionWorld::Union{Math.Vector2, Math.Vector2f}
		mousePositionWorldRaw::Union{Math.Vector2, Math.Vector2f}
		optimizeSpriteRendering::Bool
		panCounter::Union{Math.Vector2, Math.Vector2f}
		panThreshold::Float64
		scene::Scene
		selectedEntityIndex::Int64
		selectedEntityUpdated::Bool
		selectedTextBoxIndex::Int64
		screenDimensions::Math.Vector2
		shouldChangeScene::Bool
		spriteLayers::Dict
		targetFrameRate::Int32
		testLength::Float64
		testMode::Bool
		window::Ptr{SDL2.SDL_Window}
		windowName::String
		zoom::Float64

		function Main(zoom::Float64)
			this = new()

			this.zoom = zoom
			this.scene = Scene()
			this.input = Input()

			this.cameraBackgroundColor = (0,0,0)
			this.close = false
			this.debugTextBoxes = UI.TextBoxModule.TextBox[]
			this.input.scene = this.scene
			this.mousePositionWorld = Math.Vector2f()
			this.mousePositionWorldRaw = Math.Vector2f()
			this.lastMousePositionWorld = Math.Vector2f()
			this.optimizeSpriteRendering = false
			this.selectedEntityIndex = -1
			this.selectedTextBoxIndex = -1
			this.selectedEntityUpdated = false
			this.screenDimensions = Math.Vector2(0,0)
			this.shouldChangeScene = false
			this.globals = []
			this.input.main = this

			this.currentTestTime = 0.0
			this.testMode = false
			this.testLength = 0.0

			return this
		end
	end

	function Base.getproperty(this::Main, s::Symbol)
        method_props = (
            init = init,
            initializeNewScene = initialize_new_scene,
            resetCameraPosition = reset_camera_position,
            fullLoop = full_loop,
            gameLoop = game_loop,
            createNewEntity = create_new_entity,
            createNewTextBox = create_new_text_box,
            minimizeWindow = minimize_window,
            restoreWindow = restore_window,
            updateViewport = update_viewport,
            scaleZoom = scale_zoom
        )
		deprecated_get_property(method_props, this, s)
	end

    function init(this::Main, isUsingEditor = false, dimensions = C_NULL, isResizable::Bool = false, autoScaleZoom::Bool = true, isNewEditor::Bool = false)
        if !isNewEditor
            PrepareWindow(this, isUsingEditor, dimensions, isResizable, autoScaleZoom)
        end
        InitializeScriptsAndComponents(this, isUsingEditor)

        if !isUsingEditor
            this.fullLoop()
            return
        end
    end

    function initialize_new_scene(this::Main, isUsingEditor::Bool = false)
        SceneBuilderModule.change_scene(this.level, isUsingEditor)
        InitializeScriptsAndComponents(this, false)

        if !isUsingEditor
            this.fullLoop()
            return
        end
    end

    function reset_camera_position(this::Main)
        cameraPosition = Math.Vector2f()
        this.scene.camera.update(cameraPosition)
    end
	
    function full_loop(this::Main)
        try
            DEBUG = false
            this.close = false
            startTime = Ref(UInt64(0))
            lastPhysicsTime = Ref(UInt64(SDL2.SDL_GetTicks()))

            while !this.close
                try
                    GameLoop(this, startTime, lastPhysicsTime, false, C_NULL)
                catch e
                    if this.testMode
                        throw(e)
                    else
                        println(e)
                        Base.show_backtrace(stdout, catch_backtrace())
                    end
                end
                if this.testMode && this.currentTestTime >= this.testLength
                    break
                end
            end
        finally
            for entity in this.scene.entities
                for script in entity.scripts
                    try
                        script.onShutDown()
                    catch e
                        if typeof(e) != ErrorException || !contains(e.msg, "onShutDown")
                            println("Error shutting down script")
                            println(e)
                            Base.show_backtrace(stdout, catch_backtrace())
                        end
                    end
                end
            end
            if !this.shouldChangeScene
                SDL2.SDL_DestroyRenderer(JulGame.Renderer)
                SDL2.SDL_DestroyWindow(this.window)
                SDL2.SDL_Quit()
            else
                this.shouldChangeScene = false
                this.initializeNewScene(false)
            end
        end
    end

    function game_loop(this::Main, startTime::Ref{UInt64} = Ref(UInt64(0)), lastPhysicsTime::Ref{UInt64} = Ref(UInt64(0)), isEditor::Bool = false, update::Union{Ptr{Nothing}, Vector{Any}} = C_NULL, windowPos::Math.Vector2 = Math.Vector2(0,0), windowSize::Math.Vector2 = Math.Vector2(0,0))
        if this.shouldChangeScene
            this.shouldChangeScene = false
            this.initializeNewScene(true)
            return
        end
        return GameLoop(this, startTime, lastPhysicsTime, isEditor, update, windowPos, windowSize)
    end

    function handle_editor_inputs_camera(this::Main, windowPos::Math.Vector2)
        #Rendering
        cameraPosition = this.scene.camera.position
        if SDL2.SDL_BUTTON_MIDDLE in this.input.mouseButtonsHeldDown
            xDiff = this.lastMousePosition.x - this.input.mousePosition.x
            xDiff = xDiff == 0 ? 0 : (xDiff > 0 ? 0.1 : -0.1)
            yDiff = this.lastMousePosition.y - this.input.mousePosition.y
            yDiff = yDiff == 0 ? 0 : (yDiff > 0 ? 0.1 : -0.1)

            this.panCounter = Math.Vector2f(this.panCounter.x + xDiff, this.panCounter.y + yDiff)

            if this.panCounter.x > this.panThreshold || this.panCounter.x < -this.panThreshold
                diff = this.panCounter.x > this.panThreshold ? 0.2 : -0.2
                cameraPosition = Math.Vector2f(cameraPosition.x + diff, cameraPosition.y)
                this.panCounter = Math.Vector2f(0, this.panCounter.y)
            end
            if this.panCounter.y > this.panThreshold || this.panCounter.y < -this.panThreshold
                diff = this.panCounter.y > this.panThreshold ? 0.2 : -0.2
                cameraPosition = Math.Vector2f(cameraPosition.x, cameraPosition.y + diff)
                this.panCounter = Math.Vector2f(this.panCounter.x, 0)
            end
        elseif this.input.getMouseButtonPressed(SDL2.SDL_BUTTON_LEFT)
            select_entity_with_click(this, windowPos)
        elseif this.input.getMouseButton(SDL2.SDL_BUTTON_LEFT) && (this.selectedEntityIndex != -1 || this.selectedTextBoxIndex != -1) && this.selectedEntityIndex != this.selectedTextBoxIndex
            # TODO: Make this work for textboxes
            snapping = false
            if this.input.getButtonHeldDown("LCTRL")
                snapping = true
            end
            xDiff = this.lastMousePositionWorld.x - this.mousePositionWorld.x
            yDiff = this.lastMousePositionWorld.y - this.mousePositionWorld.y

            this.panCounter = Math.Vector2f(this.panCounter.x + xDiff, this.panCounter.y + yDiff)

            entityToMoveTransform = this.scene.entities[this.selectedEntityIndex].transform
            if this.panCounter.x > this.panThreshold || this.panCounter.x < -this.panThreshold
                diff = this.panCounter.x > this.panThreshold ? -1 : 1
                entityToMoveTransform.position = Math.Vector2f(entityToMoveTransform.getPosition().x + diff, entityToMoveTransform.getPosition().y)
                this.panCounter = Math.Vector2f(0, this.panCounter.y)
            end
            if this.panCounter.y > this.panThreshold || this.panCounter.y < -this.panThreshold
                diff = this.panCounter.y > this.panThreshold ? -1 : 1
                entityToMoveTransform.position = Math.Vector2f(entityToMoveTransform.getPosition().x, entityToMoveTransform.getPosition().y + diff)
                this.panCounter = Math.Vector2f(this.panCounter.x, 0)
            end
        elseif !this.input.getMouseButton(SDL2.SDL_BUTTON_LEFT) && (this.selectedEntityIndex != -1)
            if this.input.getButtonHeldDown("LCTRL") && this.input.getButtonPressed("D")
                push!(this.scene.entities, deepcopy(this.scene.entities[this.selectedEntityIndex]))
                this.selectedEntityIndex = length(this.scene.entities)
            end
        elseif SDL2.SDL_BUTTON_LEFT in this.input.mouseButtonsReleased
        end

        if "SPACE" in this.input.buttonsHeldDown
            if "LEFT" in this.input.buttonsPressedDown
                this.zoom -= .1
                this.zoom = round(clamp(this.zoom, 0.2, 3); digits=1)
				SDL2.SDL_RenderSetScale(JulGame.Renderer, this.zoom, this.zoom)
            elseif "RIGHT" in this.input.buttonsPressedDown
                this.zoom += .1
                this.zoom = round(clamp(this.zoom, 0.2, 3); digits=1)

				SDL2.SDL_RenderSetScale(JulGame.Renderer, this.zoom, this.zoom)
            end
        elseif this.input.getButtonHeldDown("LEFT")
            cameraPosition = Math.Vector2f(cameraPosition.x - 0.01, cameraPosition.y)
        elseif this.input.getButtonHeldDown("RIGHT")
            cameraPosition = Math.Vector2f(cameraPosition.x + 0.01, cameraPosition.y)
        elseif this.input.getButtonHeldDown("DOWN")
            cameraPosition = Math.Vector2f(cameraPosition.x, cameraPosition.y + 0.01)
        elseif this.input.getButtonHeldDown("UP")
            cameraPosition = Math.Vector2f(cameraPosition.x, cameraPosition.y - 0.01)
        end

        this.scene.camera.update(cameraPosition)
        return cameraPosition
    end

    function create_new_entity(this::Main)
        SceneBuilderModule.create_new_entity(this.level)
    end

    function create_new_text_box(this::Main, fontPath)
        SceneBuilderModule.create_new_text_box(this.level, fontPath)
    end

    function select_entity_with_click(this::Main)
        entityIndex = 0
        for entity in this.scene.entities
            entityIndex += 1
            
            size = entity.collider != C_NULL ? Component.get_size(entity.collider) : entity.transform.getScale()
            if this.mousePositionWorldRaw.x >= entity.transform.getPosition().x && this.mousePositionWorldRaw.x <= entity.transform.getPosition().x + size.x && this.mousePositionWorldRaw.y >= entity.transform.getPosition().y && this.mousePositionWorldRaw.y <= entity.transform.getPosition().y + size.y
                if this.selectedEntityIndex == entityIndex
                    continue
                end
                this.selectedEntityIndex = entityIndex
                this.selectedTextBoxIndex = -1
                this.selectedEntityUpdated = true
                return
            end
        end
        textBoxIndex = 1
        for textBox in this.scene.textBoxes
            if this.mousePositionWorld.x >= textBox.position.x && this.mousePositionWorld.x <= textBox.position.x + textBox.size.x && this.mousePositionWorld.y >= textBox.position.y && this.mousePositionWorld.y <= textBox.position.y + textBox.size.y
                this.selectedTextBoxIndex = textBoxIndex
                this.selectedEntityIndex = -1

                return
            end
            textBoxIndex += 1
        end
        this.selectedEntityIndex = -1
    end

    function minimize_window(this::Main)
        SDL2.SDL_MinimizeWindow(this.window)
    end

    function restore_window(this::Main)
        SDL2.SDL_RestoreWindow(this.window)
    end

    function update_viewport(this::Main, x,y)
        if !this.autoScaleZoom
            return
        end
        this.scaleZoom(x,y)
        SDL2.SDL_RenderClear(JulGame.Renderer)
        SDL2.SDL_RenderSetScale(JulGame.Renderer, 1.0, 1.0)	
        this.scene.camera.startingCoordinates = Math.Vector2f(round(x/2) - round(this.scene.camera.dimensions.x/2*this.zoom), round(y/2) - round(this.scene.camera.dimensions.y/2*this.zoom))																																				
        SDL2.SDL_RenderSetViewport(JulGame.Renderer, Ref(SDL2.SDL_Rect(this.scene.camera.startingCoordinates.x, this.scene.camera.startingCoordinates.y, round(this.scene.camera.dimensions.x*this.zoom), round(this.scene.camera.dimensions.y*this.zoom))))
        SDL2.SDL_RenderSetScale(JulGame.Renderer, this.zoom, this.zoom)
    end

	function update_viewport_editor(this::Main, x,y)
        if !this.autoScaleZoom
            return
        end
        this.scaleZoom(x,y)
        SDL2.SDL_RenderClear(JulGame.Renderer)
        SDL2.SDL_RenderSetScale(JulGame.Renderer, 1.0, 1.0)	
        this.scene.camera.startingCoordinates = Math.Vector2f(round(x/2) - round(this.scene.camera.dimensions.x/2*this.zoom), round(y/2) - round(this.scene.camera.dimensions.y/2*this.zoom))																																				
        SDL2.SDL_RenderSetViewport(JulGame.Renderer, Ref(SDL2.SDL_Rect(this.scene.camera.startingCoordinates.x, this.scene.camera.startingCoordinates.y, round(this.scene.camera.dimensions.x*this.zoom), round(this.scene.camera.dimensions.y*this.zoom))))
        SDL2.SDL_RenderSetScale(JulGame.Renderer, this.zoom, this.zoom)
		println("Zoom: ", this.zoom)
    end
	

    function scale_zoom(this::Main, x,y)
        if this.autoScaleZoom
            targetRatio = this.scene.camera.dimensions.x/this.scene.camera.dimensions.y
            if this.scene.camera.dimensions.x == max(this.scene.camera.dimensions.x, this.scene.camera.dimensions.y)
                for i in x:-1:this.scene.camera.dimensions.x
                    value = i/targetRatio
                    isInt = isinteger(value) || (isa(value, AbstractFloat) && trunc(value) == value)
                    if isInt && value <= y
                        this.zoom = i/this.scene.camera.dimensions.x
                        break
                    end
                end
            else
                for i in y:-1:this.scene.camera.dimensions.y
                    value = i*targetRatio
                    isInt = isinteger(value) || (isa(value, AbstractFloat) && trunc(value) == value)
                    if isInt && value <= x
                        this.zoom = i/this.scene.camera.dimensions.y
                        break
                    end
                end
            end
        end
    end
    
	function PrepareWindow(this::Main, isUsingEditor::Bool = false, dimensions = C_NULL, isResizable::Bool = false, autoScaleZoom::Bool = true)
		if dimensions == Math.Vector2()
			displayMode = SDL2.SDL_DisplayMode[SDL2.SDL_DisplayMode(0x12345678, 800, 600, 60, C_NULL)]
			SDL2.SDL_GetCurrentDisplayMode(0, pointer(displayMode))
			dimensions = Math.Vector2(displayMode[1].w, displayMode[1].h)
		end
		this.autoScaleZoom = autoScaleZoom
		this.scaleZoom(dimensions.x,dimensions.y)

		this.screenDimensions = dimensions != C_NULL ? dimensions : this.scene.camera.dimensions

		flags = SDL2.SDL_RENDERER_ACCELERATED |
		(isUsingEditor ? (SDL2.SDL_WINDOW_POPUP_MENU | SDL2.SDL_WINDOW_ALWAYS_ON_TOP | SDL2.SDL_WINDOW_BORDERLESS) : 0) |
		(isResizable || isUsingEditor ? SDL2.SDL_WINDOW_RESIZABLE : 0) |
		(dimensions == Math.Vector2() ? SDL2.SDL_WINDOW_FULLSCREEN_DESKTOP : 0)

		this.window = SDL2.SDL_CreateWindow(this.windowName, SDL2.SDL_WINDOWPOS_CENTERED, SDL2.SDL_WINDOWPOS_CENTERED, this.screenDimensions.x, this.screenDimensions.y, flags)

		JulGame.Renderer = SDL2.SDL_CreateRenderer(this.window, -1, SDL2.SDL_RENDERER_ACCELERATED)
		this.scene.camera.startingCoordinates = Math.Vector2f(round(dimensions.x/2) - round(this.scene.camera.dimensions.x/2*this.zoom), round(dimensions.y/2) - round(this.scene.camera.dimensions.y/2*this.zoom))																																				
		SDL2.SDL_RenderSetViewport(JulGame.Renderer, Ref(SDL2.SDL_Rect(this.scene.camera.startingCoordinates.x, this.scene.camera.startingCoordinates.y, round(this.scene.camera.dimensions.x*this.zoom), round(this.scene.camera.dimensions.y*this.zoom))))
		# windowInfo = unsafe_wrap(Array, SDL2.SDL_GetWindowSurface(this.window), 1; own = false)[1]

		SDL2.SDL_RenderSetScale(JulGame.Renderer, this.zoom, this.zoom)
	end

function InitializeScriptsAndComponents(this::Main, isUsingEditor::Bool = false)
	scripts = []
	for entity in this.scene.entities
		for script in entity.scripts
			push!(scripts, script)
		end
	end

	for textBox in this.scene.textBoxes
        JulGame.initialize(textBox)
	end
	for screenButton in this.scene.screenButtons
        JulGame.initialize(screenButton)
	end

	this.lastMousePosition = Math.Vector2(0, 0)
	this.panCounter = Math.Vector2f(0, 0)
	this.panThreshold = .1

	this.spriteLayers = BuildSpriteLayers(this)
	
	if !isUsingEditor
		for script in scripts
			try
				script.initialize()
			catch e
				if typeof(e) != ErrorException || !contains(e.msg, "initialize")
					println("Error initializing script")
					println(e)
					Base.show_backtrace(stdout, catch_backtrace())
				end
			end
		end
	end
end

export change_scene
"""
	change_scene(sceneFileName::String)

Change the scene to the specified `sceneFileName`. This function destroys the current scene, including all entities, textboxes, and screen buttons, except for the ones marked as persistent. It then loads the new scene and sets the camera and persistent entities, textboxes, and screen buttons.

# Arguments
- `sceneFileName::String`: The name of the scene file to load.

"""
function change_scene(sceneFileName::String)
	# println("Changing scene to: ", sceneFileName)
	MAIN.close = true
	MAIN.shouldChangeScene = true
	#destroy current scene 
	#println("Entities before destroying: ", length(MAIN.scene.entities))
	count = 0
	skipcount = 0
	persistentEntities = []	
	for entity in MAIN.scene.entities
		if entity.persistentBetweenScenes
			#println("Persistent entity: ", entity.name, " with id: ", entity.id)
			push!(persistentEntities, entity)
			skipcount += 1
			continue
		end

		DestroyEntityComponents(entity)
		for script in entity.scripts
			try
				script.onShutDown()
			catch e
				if typeof(e) != ErrorException || !contains(e.msg, "onShutDown")
					println("Error shutting down script")
					println(e)
					Base.show_backtrace(stdout, catch_backtrace())
				end
			end
		end
		count += 1
	end
	# println("Destroyed $count entities")
	# println("Skipped $skipcount entities")

	# println("Entities left after destroying: ", length(persistentEntities))

	persistentTextBoxes = []
	# delete all textboxes
	for textBox in MAIN.scene.textBoxes
		if textBox.persistentBetweenScenes
			#println("Persistent textBox: ", textBox.name)
			push!(persistentTextBoxes, textBox)
			skipcount += 1
			continue
		end
        JulGame.destroy(textBox)
	end
	
	persistentScreenButtons = []
	# delete all screen buttons
	for screenButton in MAIN.scene.screenButtons
		if screenButton.persistentBetweenScenes
			#println("Persistent screenButton: ", screenButton.name)
			push!(persistentScreenButtons, screenButton)
			skipcount += 1
			continue
		end

		screenButton.destroy()
	end
	
	#load new scene 
	camera = MAIN.scene.camera
	MAIN.scene = Scene()
	MAIN.scene.entities = persistentEntities
	MAIN.scene.textBoxes = persistentTextBoxes
	MAIN.scene.screenButtons = persistentScreenButtons
	MAIN.scene.camera = camera
	MAIN.level.scene = sceneFileName
end

"""
BuildSpriteLayers(main::Main)

Builds the sprite layers for the main game.

# Arguments
- `main::Main`: The main game object.

"""
function BuildSpriteLayers(main::Main)
	layerDict = Dict{String, Array}()
	layerDict["sort"] = []
	for entity in main.scene.entities
		entitySprite = entity.sprite
		if entitySprite != C_NULL
			if !haskey(layerDict, "$(entitySprite.layer)")
				push!(layerDict["sort"], entitySprite.layer)
				layerDict["$(entitySprite.layer)"] = [entitySprite]
			else
				push!(layerDict["$(entitySprite.layer)"], entitySprite)
			end
		end
	end
	sort!(layerDict["sort"])

	return layerDict
end

export DestroyEntity
"""
DestroyEntity(entity)

Destroy the specified entity. This removes the entity's sprite from the sprite layers so that it is no longer rendered. It also removes the entity's rigidbody from the main game's rigidbodies array.

# Arguments
- `entity`: The entity to be destroyed.
"""
function DestroyEntity(entity)
	for i = 1:length(MAIN.scene.entities)
		if MAIN.scene.entities[i] == entity
			#	println("Destroying entity: ", entity.name, " with id: ", entity.id, " at index: ", index)
			DestroyEntityComponents(entity)
			deleteat!(MAIN.scene.entities, i)
			break
		end
	end
end

function DestroyEntityComponents(entity)
	entitySprite = entity.sprite
	if entitySprite != C_NULL
		for j = 1:length(MAIN.spriteLayers["$(entitySprite.layer)"])
			if MAIN.spriteLayers["$(entitySprite.layer)"][j] == entitySprite
				entitySprite.destroy()
				deleteat!(MAIN.spriteLayers["$(entitySprite.layer)"], j)
				break
			end
		end
	end

	entityRigidbody = entity.rigidbody
	if entityRigidbody != C_NULL
		for j = 1:length(MAIN.scene.rigidbodies)
			if MAIN.scene.rigidbodies[j] == entityRigidbody
				deleteat!(MAIN.scene.rigidbodies, j)
				break
			end
		end
	end

	entityCollider = entity.collider
	if entityCollider != C_NULL
		for j = 1:length(MAIN.scene.colliders)
			if MAIN.scene.colliders[j] == entityCollider
				deleteat!(MAIN.scene.colliders, j)
				break
			end
		end
	end

	entitySoundSource = entity.soundSource
	if entitySoundSource != C_NULL
		entitySoundSource.unloadSound()
	end
end

export CreateEntity
"""
CreateEntity(entity)

Create a new entity. Adds the entity to the main game's entities array and adds the entity's sprite to the sprite layers so that it is rendered.

# Arguments
- `entity`: The entity to create.

"""
function CreateEntity(entity)
	push!(MAIN.scene.entities, entity)
	if entity.sprite != C_NULL
		if !haskey(MAIN.spriteLayers, "$(entity.sprite.layer)")
			push!(MAIN.spriteLayers["sort"], entity.sprite.layer)
			MAIN.spriteLayers["$(entity.sprite.layer)"] = [entity.sprite]
			sort!(MAIN.spriteLayers["sort"])
		else
			push!(MAIN.spriteLayers["$(entity.sprite.layer)"], entity.sprite)
		end
	end

	if entity.rigidbody != C_NULL
		push!(MAIN.scene.rigidbodies, entity.rigidbody)
	end

	if entity.collider != C_NULL
		push!(MAIN.scene.colliders, entity.collider)
	end

	return entity
end

"""
GameLoop(this, startTime::Ref{UInt64} = Ref(UInt64(0)), lastPhysicsTime::Ref{UInt64} = Ref(UInt64(0)), close::Ref{Bool} = Ref(Bool(false)), isEditor::Bool = false, update::Union{Ptr{Nothing}, Vector{Any}} = C_NULL)

Runs the game loop.

Parameters:
- `this`: The main struct.
- `startTime`: A reference to the start time of the game loop.
- `lastPhysicsTime`: A reference to the last physics time of the game loop.
- `isEditor`: A boolean indicating whether the game loop is running in editor mode.
- `update`: An array containing information to pass back to the editor.

"""
function GameLoop(this::Main, startTime::Ref{UInt64} = Ref(UInt64(0)), lastPhysicsTime::Ref{UInt64} = Ref(UInt64(0)), isEditor::Bool = false, update::Union{Ptr{Nothing}, Vector{Any}} = C_NULL, windowPos::Math.Vector2 = Math.Vector2(0,0), windowSize::Math.Vector2 = Math.Vector2(0,0))
        try
			SDL2.SDL_RenderSetScale(JulGame.Renderer, this.zoom, this.zoom)

			lastStartTime = startTime[]
			startTime[] = SDL2.SDL_GetPerformanceCounter()

			x,y,w,h = Int32[1], Int32[1], Int32[1], Int32[1]
			if isEditor && update != C_NULL
				SDL2.SDL_GetWindowPosition(this.window, pointer(x), pointer(y))
				SDL2.SDL_GetWindowSize(this.window, pointer(w), pointer(h))

				if update[2] != x[1] || update[3] != y[1]
					if (update[2] < 2147483648 && update[3] < 2147483648)
						SDL2.SDL_SetWindowPosition(this.window, round(update[2]), round(update[3]))
					end
				end
				if update[4] != w[1] || update[5] != h[1]
					SDL2.SDL_SetWindowSize(this.window, round(update[4]), round(update[5]))
					SDL2.SDL_RenderSetScale(JulGame.Renderer, this.zoom, this.zoom)
				end
			end
			if isEditor && update == C_NULL
				this.scene.camera.dimensions = Math.Vector2(windowSize.x, windowSize.y)
				# update_viewport_editor(this, windowSize.x, windowSize.y)
			end

			DEBUG = false
			#region =============    Input
			this.lastMousePosition = this.input.mousePosition
			if !isEditor
				this.input.pollInput()
			end

			if this.input.quit && !isEditor
				this.close = true
			end
			DEBUG = this.input.debug

			cameraPosition = Math.Vector2f()
			if isEditor
				cameraPosition = handle_editor_inputs_camera(this, windowPos)
			end

			#endregion ============= Input

			if !isEditor || update != C_NULL
				SDL2.SDL_RenderClear(JulGame.Renderer)
			end

			#region =============    Physics
			if !isEditor
				currentPhysicsTime = SDL2.SDL_GetTicks()
				deltaTime = (currentPhysicsTime - lastPhysicsTime[]) / 1000.0

				this.currentTestTime += deltaTime
				if deltaTime > .25
					lastPhysicsTime[] =  SDL2.SDL_GetTicks()
					return
				end
				for rigidbody in this.scene.rigidbodies
					try
						JulGame.update(rigidbody, deltaTime)
					catch e
						println(rigidbody.parent.name, " with id: ", rigidbody.parent.id, " has a problem with it's rigidbody")
						rethrow(e)
					end
				end
				lastPhysicsTime[] =  currentPhysicsTime
			end
			#endregion ============= Physics


			#region =============    Rendering
			currentRenderTime = SDL2.SDL_GetTicks()
			SDL2.SDL_SetRenderDrawColor(JulGame.Renderer, 0, 200, 0, SDL2.SDL_ALPHA_OPAQUE)
			this.scene.camera.update()

			for entity in this.scene.entities
				if !entity.isActive
					continue
				end

				if !isEditor
					try
                        JulGame.update(entity, deltaTime)
						if this.close
							return
						end
					catch e
						println(entity.name, " with id: ", entity.id, " has a problem with it's update")
						rethrow(e)
					end
					entityAnimator = entity.animator
					if entityAnimator != C_NULL
                        JulGame.update(entityAnimator, currentRenderTime, deltaTime)
					end
				end
			end

			# Used for conditional rendering
			cameraPosition = this.scene.camera.position
			cameraSize = this.scene.camera.dimensions
			if !isEditor || update == C_NULL
				skipcount = 0
				rendercount = 0
				for layer in this.spriteLayers["sort"]
					for sprite in this.spriteLayers["$(layer)"]
						spritePosition = sprite.parent.transform.getPosition()
						spriteSize = sprite.parent.transform.getScale()
						
						if ((spritePosition.x + spriteSize.x) < cameraPosition.x || spritePosition.y < cameraPosition.y || spritePosition.x > cameraPosition.x + cameraSize.x/SCALE_UNITS || (spritePosition.y - spriteSize.y) > cameraPosition.y + cameraSize.y/SCALE_UNITS) && sprite.isWorldEntity && this.optimizeSpriteRendering 
							skipcount += 1
							continue
						end
						rendercount += 1
						try
							Component.draw(sprite)
						catch e
							println(sprite.parent.name, " with id: ", sprite.parent.id, " has a problem with it's sprite")
							rethrow(e)
						end
					end
				end
				#println("Skipped $skipcount, rendered $rendercount")
			end

			colliderSkipCount = 0
			colliderRenderCount = 0
			for entity in this.scene.entities
				if !entity.isActive
					continue
				end

				entityShape = entity.shape
				if entityShape != C_NULL
					entityShape.draw()
				end

				
				if DEBUG && entity.collider != C_NULL
					SDL2.SDL_SetRenderDrawColor(JulGame.Renderer, 0, 255, 0, SDL2.SDL_ALPHA_OPAQUE)
					pos = entity.transform.getPosition()
					scale = entity.transform.getScale()

					if ((pos.x + scale.x) < cameraPosition.x || pos.y < cameraPosition.y || pos.x > cameraPosition.x + cameraSize.x/SCALE_UNITS || (pos.y - scale.y) > cameraPosition.y + cameraSize.y/SCALE_UNITS)  && this.optimizeSpriteRendering 
						colliderSkipCount += 1
						continue
					end
					colliderRenderCount += 1
					collider = entity.collider
					zoomMultiplier = (isEditor && update == C_NULL) ? this.zoom : 1.0
					if JulGame.get_type(collider) == "CircleCollider"
						SDL2E.SDL_RenderDrawCircle(
							round(Int32, (pos.x - this.scene.camera.position.x) * SCALE_UNITS - ((entity.transform.getScale().x * SCALE_UNITS - SCALE_UNITS) / 2)), 
							round(Int32, (pos.y - this.scene.camera.position.y) * SCALE_UNITS - ((entity.transform.getScale().y * SCALE_UNITS - SCALE_UNITS) / 2)), 
							round(Int32, collider.diameter/2 * SCALE_UNITS))
					else
						colSize = JulGame.get_size(collider)
						colSize = Math.Vector2f(colSize.x * zoomMultiplier, colSize.y * zoomMultiplier)
						colOffset = collider.offset
						colOffset = Math.Vector2f(colOffset.x, colOffset.y)

						SDL2.SDL_RenderDrawRectF(JulGame.Renderer, 
						Ref(SDL2.SDL_FRect((pos.x + colOffset.x - this.scene.camera.position.x) * SCALE_UNITS - ((entity.transform.getScale().x * SCALE_UNITS - SCALE_UNITS) / 2) - ((colSize.x * SCALE_UNITS - SCALE_UNITS) / 2), 
						(pos.y + colOffset.y - this.scene.camera.position.y) * SCALE_UNITS - ((entity.transform.getScale().y * SCALE_UNITS - SCALE_UNITS) / 2) - ((colSize.y * SCALE_UNITS - SCALE_UNITS) / 2), 
						colSize.x * SCALE_UNITS, 
						colSize.y * SCALE_UNITS)))
					end
				end
			end
			#println("Skipped $colliderSkipCount, rendered $colliderRenderCount")

			#endregion ============= Rendering

			#region ============= UI
			for screenButton in this.scene.screenButtons
				screenButton.render()
			end

			for textBox in this.scene.textBoxes
                JulGame.render(textBox, DEBUG)
			end
			#endregion ============= UI

			if isEditor
				SDL2.SDL_SetRenderDrawColor(JulGame.Renderer, 255, 0, 0, SDL2.SDL_ALPHA_OPAQUE)
			end
			if isEditor
				selectedEntity = this.selectedEntityIndex > 0 ? this.scene.entities[this.selectedEntityIndex] : C_NULL
				try
					if selectedEntity != C_NULL
						if this.input.getButtonPressed("DELETE")
							println("delete entity with name $(selectedEntity.name) and id $(selectedEntity.id)")
						end

						pos = selectedEntity.transform.getPosition()
                        
						size = selectedEntity.collider != C_NULL ? JulGame.get_size(selectedEntity.collider) : selectedEntity.transform.getScale()
						size = Math.Vector2f(size.x * zoomMultiplier, size.y * zoomMultiplier)
						offset = selectedEntity.collider != C_NULL ? selectedEntity.collider.offset : Math.Vector2f()
						offset = Math.Vector2f(offset.x, offset.y)
						SDL2.SDL_RenderDrawRectF(JulGame.Renderer, 
						Ref(SDL2.SDL_FRect((pos.x + offset.x - this.scene.camera.position.x) * SCALE_UNITS - ((size.x * SCALE_UNITS - SCALE_UNITS) / 2) - ((size.x * SCALE_UNITS - SCALE_UNITS) / 2), 
						(pos.y + offset.y - this.scene.camera.position.y) * SCALE_UNITS - ((size.y * SCALE_UNITS - SCALE_UNITS) / 2) - ((size.y * SCALE_UNITS - SCALE_UNITS) / 2), 
						size.x * SCALE_UNITS, 
						size.y * SCALE_UNITS)))
					end
				catch e
					rethrow(e)
				end
			end
			if isEditor
				SDL2.SDL_SetRenderDrawColor(JulGame.Renderer, 0, 200, 0, SDL2.SDL_ALPHA_OPAQUE)
			end

			this.lastMousePositionWorld = this.mousePositionWorld
			pos1::Math.Vector2 = windowPos !== nothing ? windowPos : Math.Vector2(0, 0)
			this.mousePositionWorldRaw = Math.Vector2f((this.input.mousePosition.x - pos1.x + (this.scene.camera.position.x * SCALE_UNITS * this.zoom)) / SCALE_UNITS / this.zoom, ( this.input.mousePosition.y - pos1.y + (this.scene.camera.position.y * SCALE_UNITS * this.zoom)) / SCALE_UNITS / this.zoom)
			this.mousePositionWorld = Math.Vector2(floor(Int32,(this.input.mousePosition.x + (this.scene.camera.position.x * SCALE_UNITS * this.zoom)) / SCALE_UNITS / this.zoom), floor(Int32,( this.input.mousePosition.y + (this.scene.camera.position.y * SCALE_UNITS * this.zoom)) / SCALE_UNITS / this.zoom))
			rawMousePos = Math.Vector2f(this.input.mousePosition.x - pos1.x , this.input.mousePosition.y - pos1.y )
			#region ================ Debug
			if DEBUG
				# Stats to display
				statTexts = [
					"FPS: $(round(1000 / round((startTime[] - lastStartTime) / SDL2.SDL_GetPerformanceFrequency() * 1000.0)))",
					"Frame time: $(round((startTime[] - lastStartTime) / SDL2.SDL_GetPerformanceFrequency() * 1000.0)) ms",
					"Raw Mouse pos: $(rawMousePos.x),$(rawMousePos.y)",
					"Mouse pos world: $(this.mousePositionWorld.x),$(this.mousePositionWorld.y)"
				]

				if length(this.debugTextBoxes) == 0
					fontPath = joinpath(this.assets, "fonts", "FiraCode", "ttf", "FiraCode-Regular.ttf")

					for i = 1:length(statTexts)
						textBox = UI.TextBoxModule.TextBox("Debug text", fontPath, 40, Math.Vector2(0, 35 * i), statTexts[i], false, false, true)
						push!(this.debugTextBoxes, textBox)
                        JulGame.initialize(textBox)
					end
				else
					for i = 1:length(this.debugTextBoxes)
                        db_textbox = this.debugTextBoxes[i]
                        JulGame.update_text(db_textbox, statTexts[i])
                        JulGame.render(db_textbox, false)
					end
				end
			end

			#endregion ============= Debug

			if !isEditor || update != C_NULL
				SDL2.SDL_RenderPresent(JulGame.Renderer)
			end
			endTime = SDL2.SDL_GetPerformanceCounter()
			elapsedMS = (endTime - startTime[]) / SDL2.SDL_GetPerformanceFrequency() * 1000.0
			targetFrameTime::Float64 = 1000/this.targetFrameRate

			if elapsedMS < targetFrameTime && !isEditor
				SDL2.SDL_Delay(round(targetFrameTime - elapsedMS))
			end

			if isEditor && update != C_NULL 
				returnData = [[this.scene.entities, this.scene.textBoxes, this.scene.screenButtons], this.mousePositionWorld, cameraPosition, !this.selectedEntityUpdated ? update[7] : this.selectedEntityIndex, this.input.isWindowFocused] 
				this.selectedEntityUpdated = false 
				return returnData 
			end 
		catch e
			if this.testMode || isEditor
				rethrow(e)
			else
				println("$(e)")
				Base.show_backtrace(stderr, catch_backtrace())
			end
		end
    end
end
