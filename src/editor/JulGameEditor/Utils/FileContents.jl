sceneJsonContents = "{
    \"Entities\": [ ],
    \"UIElements\": [ ]
}"


gitIgnoreFileContent = "# Files generated by invoking Julia with --code-coverage
*.jl.cov
*.jl.*.cov

# Files generated by invoking Julia with --track-allocation
*.jl.mem

# System-specific files and directories generated by the BinaryProvider and BinDeps packages
# They contain absolute paths specific to the host computer, and so should not be committed
deps/deps.jl
deps/build.log
deps/downloads/
deps/usr/
deps/src/

# Build artifacts for creating documentation generated by the Documenter package
docs/build/
docs/site/

# Build artifacts for PackageCompiler builds
/Build

# File generated by Pkg, the package manager, based on a corresponding Project.toml
# It records a fixed state of all packages used by the project. As such, it should not be
# committed for packages, but should be committed for applications that require a static
# environment.
Manifest.toml
"

function readMeFileContent(projectName)
    return "# $projectName \n Made with JulGame.jl: https://github.com/Kyjor/JulGame.jl \nHow to run from command line: cd $projectName\\src then run \"julia Run.jl\""
end

function mainFileContent(projectName)
    return "module $projectName 
        using JulGame
        using JulGame.Math

        function run()
            JulGame.MAIN = JulGame.Main(Float64(1.0))
            JulGame.PIXELS_PER_UNIT = 16
            scene = SceneBuilderModule.Scene(\"scene.json\")
            SceneBuilderModule.load_and_prepare_scene(scene, \"$projectName\", Vector2(1280, 720),Vector2(1920, 1080), false, 1.0, true, 60)
        end

        julia_main() = run()
    end"
end

function runFileContent(projectName)
    return "include(\"$projectName.jl\")

    using .$projectName

    $projectName.julia_main()"
end

function precompileFileContent(projectName)
    return "using $projectName

    $projectName.julia_main()"
end

function projectTomlContent(projectName)
    return "name = \"$projectName\"
    uuid = \"$(JulGame.generate_uuid())\"
    authors = [\"Your Name Here\"]
    version = \"0.1.0\"

    [deps]
    JulGame = \"4850f9bb-d191-4a1e-9f97-ee64062927c3\""
end

function newScriptContent(scriptName)
    return "module $scriptNamemodule
    mutable struct $scriptName
    parent # do not remove this line, this is a reference to the entity that this script is attached to
    # This is where you define your script's fields
    # Example: speed::Float64

        function $scriptName()
            this = new() # do not remove this line
            
            # this is where you initialize your script's fields
            # Example: this.speed = 1.0
            

            return this # do not remove this line
        end
    end

    # This is called when a scene is loaded, or when script is added to an entity
    # This is where you should register collision events or other events
    # Do not remove this function
    function JulGame.initialize(this::$scriptName)
    end

    # This is called every frame
    # Do not remove this function
    function JulGame.update(this::$scriptName, deltaTime)
    end

    # This is called when the script is removed from an entity (scene change, entity deletion)
    # Do not remove this function
    function JulGame.on_shutdown(this::$scriptName)
    end 
end
"
end

function config_file_content(projectName)
    return
    "WindowName=$projectName
Width=800
Height=800
CameraWidth=800
CameraHeight=800
IsResizable=1
Zoom=1.0
AutoScaleZoom=0
FrameRate=60"
end