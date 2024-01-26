﻿module RigidbodyModule
    using ..Component.JulGame
    import ..Component.JulGame: deprecated_get_property
    export Rigidbody
    struct Rigidbody
        mass::Float64
        useGravity::Bool

        function Rigidbody(;mass::Float64 = 1.0, useGravity::Bool = true)
            return new(mass, useGravity)
        end
    end

    export InternalRigidbody
    mutable struct InternalRigidbody 
        acceleration::Math.Vector2f
        drag::Float64
        grounded::Bool
        mass::Float64
        offset::Math.Vector2f
        parent::Any
        useGravity::Bool
        velocity::Math.Vector2f

        function InternalRigidbody(parent::Any; mass::Float64 = 1.0, useGravity::Bool = true)
            this = new()
            
            this.acceleration = Math.Vector2f()
            this.drag = 0.1
            this.grounded = false
            this.mass = mass
            this.offset = Math.Vector2f()
            this.parent = parent
            this.useGravity = useGravity
            this.velocity = Math.Vector2f(0.0, 0.0)

            return this
        end
    end

    function Base.getproperty(this::InternalRigidbody, s::Symbol)
        # Todo: update this based on offset and scale
        method_props = (
            update = update,
            applyForces = apply_forces,
            getVelocity = get_velocity,
            getParent = get_parent,
            setVector2fValue = set_vector2f_value
        )
        deprecated_get_property(method_props, this, s)
    end

    function update(this::InternalRigidbody, dt)
        velocityMultiplier = Math.Vector2f(1.0, 1.0)
        transform = this.parent.transform
        currentPosition = transform.getPosition()
        
        newPosition = transform.getPosition() + this.velocity*dt + this.acceleration*(dt*dt*0.5)
        if this.grounded
            newPosition = Math.Vector2f(newPosition.x, currentPosition.y)
            velocityMultiplier = Math.Vector2f(1.0, 0.0)
        end
        newAcceleration = this.applyForces()
        newVelocity = this.velocity + (this.acceleration+newAcceleration)*(dt*0.5)

        transform.setPosition(newPosition)
        SetVelocity(this, newVelocity * velocityMultiplier)
        this.acceleration = newAcceleration

        if this.parent.collider != C_NULL
            this.parent.collider.checkCollisions()
        end
    end

    function apply_forces(this::InternalRigidbody)
        gravityAcceleration = Math.Vector2f(0.0, this.useGravity ? GRAVITY : 0.0)
        dragForce = 0.5 * this.drag * (this.velocity * this.velocity)
        dragAcceleration = dragForce / this.mass
        return gravityAcceleration - dragAcceleration
    end

    function get_velocity(this::InternalRigidbody)
        return this.velocity
    end

    function get_parent(this::InternalRigidbody)
        return this.parent
    end

    function set_vector2f_value(this::InternalRigidbody, field, x, y)
        setfield!(this, field, Math.Vector2f(x,y))
    end


    """
    AddVelocity(this::Rigidbody, velocity::Math.Vector2f)

    Add the given velocity to the Rigidbody's current velocity. If the y-component of the velocity is positive, set the `grounded` flag to false.
    
    # Arguments
    - `this::Rigidbody`: The Rigidbody component to set the velocity for.
    - `velocity::Math.Vector2f`: The velocity to set.
    """
    function AddVelocity(this::InternalRigidbody, velocity::Math.Vector2f)
        this.velocity = this.velocity + velocity
        if(velocity.y < 0)
            this.grounded = false
            if this.parent.collider != C_NULL
                this.parent.collider.currentRests = []
            end
        end
    end
    export AddVelocity
    
    """
    SetVelocity(this::Rigidbody, velocity::Math.Vector2f)

    Set the velocity of the Rigidbody component.

    # Arguments
    - `this::Rigidbody`: The Rigidbody component to set the velocity for.
    - `velocity::Vector2f`: The velocity to set.
    """
    function SetVelocity(this::InternalRigidbody, velocity::Math.Vector2f)
        this.velocity = velocity
        if(velocity.y < 0)
            #this.grounded = false
        end
    end
    export SetVelocity
end
