__precompile__()
include("Math/Vector2f.jl")
using SimpleDirectMediaLayer.LibSDL2

mutable struct Collider
    
   size::Vector2f
   offset
   parent
   tag
    
    function Collider(size::Vector2f, offset::Vector2f, tag)
        this = new()

        this.size = size
        this.offset = offset
        this.tag = tag
        println("get size ")
        println(this.getSize())
        return this
    end
end

function Base.getproperty(this::Collider, s::Symbol)
    if s == :getSize
        function()
            return this.size
        end
    elseif s == :setSize
        function(size::Vector2f)
            this.size = size
        end
    elseif s == :getOffset
        function()
            return this.offset
        end
    elseif s == :setOffset
        function(offset::Vector2f)
            this.offset = offset
        end
    elseif s == :getTag
        function()
            return this.tag
        end
    elseif s == :setTag
        function(tag)
            this.tag = tag
        end
    elseif s == :getParent
        function()
            return this.parent
        end
    elseif s == :setParent
        function(parent)
            this.parent = parent
        end
    elseif s == :update
        function()
            #this.parent = parent
        end
    else
        getfield(this, s)
    end
end