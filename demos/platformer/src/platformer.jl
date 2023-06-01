module platformer
    using julGame.SceneBuilderModule
    #include("../scenes/level_1.jl")
    using SimpleDirectMediaLayer
    const SDL2 = SimpleDirectMediaLayer 

    function run(isUsingEditor = false)
        SDL2.init()
        if isUsingEditor
            dir = @__DIR__
        else
            dir = pwd()
        end
        scene = Scene(dir, "scene.json")
        return scene.init(isUsingEditor)
    end

    julia_main() = run()
end