local actor = nil
local click_timer = Timer()
local targetPosition = nil

local waypoints = {}

local function RemoveActor()
    if actor then
        actor:Remove()
        actor = nil
    end
end

local function CreateActor()
    RemoveActor()
    
    actor = ClientActor.Create(AssetLocation.Game, {
        model_id = 3,
        position = Camera:GetPosition(),
        angle = Angle.Zero
    })
end

Events:Subscribe(
    'ModuleUnload',
    function()
        RemoveActor()
    end
)

Events:Subscribe(
    'LocalPlayerInput',
    function(e)
        -- Update the pathfinding target
        if e.input == Action.FireRight then
            if click_timer:GetSeconds() > 0.2 then
                click_timer:Restart()
                
                if not actor then
                    Chat:Print('You need to spawn a ClientActor. Right click somewhere in the world first', Color.Red)
                    return 
                end
                
                -- Find the point in the world that the Camera is aiming at
                targetPosition = Physics:Raycast(Camera:GetPosition(), Camera:GetAngle() * Vector3.Forward, 0, 200).position
                
                waypoints = {}
                local allowedArrivalOffset = 0
                local allowedTargetOffset = 0
                -- Issue a new pathfinding request to the target
                -- Note: Existing requests will be cancelled
                actor:FindShortestPath(
                    targetPosition,
                    allowedArrivalOffset,
                    allowedTargetOffset,
                    function(args)
                        -- We got a path to traverse!
                        -- Note that this may occur multiple times as the ClientActor moves through
                        -- the world and avoidable obstacles are identified.
                        if args.state == PathFindState.PathUpdate then
                            Chat:Print("Path Updated: " .. tostring(#args.waypoints) .. " waypoints", Color.LawnGreen)
                            
                            -- The returned paths are in 2D-space, so we need to fill in the heights
                            -- ourselves by raycasting down to the terrain from the sky.
                            for _, v in pairs(args.waypoints) do
                                local height = Physics:GetTerrainHeight(v)
                                v.y = Physics:Raycast(Vector3(v.x, height + 120, v.z), Vector3.Down, 0, 200).position.y
                            end
                            
                            waypoints = args.waypoints
                        elseif args.state == PathFindState.PathEndReach then
                            Chat:Print("Reached end of path", Color.LawnGreen)
                        elseif args.state == PathFindState.PathFailed then
                            Chat:Print("Path failed", Color.Red)
                        elseif args.state == PathFindState.PathNextWaypointChange then
                            Chat:Print("Next waypoint update: " .. tostring(args.next_waypoint_index), Color.Blue)
                        end
                    end
                )
            end
        end
        
        -- Relocate the Actor to where the camera is pointing
        if e.input == Action.FireLeft then
            if not actor then
                CreateActor()
            end
            
            if actor then
                local pos = Physics:Raycast(Camera:GetPosition(), Camera:GetAngle() * Vector3.Forward, 0, 200).position
                actor:SetPosition(pos)
            end
        end
    end
)

Events:Subscribe(
    'Render',
    function()
        if targetPosition then
            local pos, valid = Render:WorldToScreen(targetPosition)
            if valid then
                Render:DrawText(pos, "Target", Color.LawnGreen)
            end
        end
        
        for i, node1 in pairs(waypoints) do
            local node2 = waypoints[i + 1]
            local color = Color.FromHSV((i - 1) / #waypoints * 360, 0.7, 1.0)
            
            local pos, valid = Render:WorldToScreen(node1)
            if valid then
                Render:DrawText(pos, string.format("#%i", tostring(i)), color)
            end
            
            if node2 then
                Render:DrawLine(node1, node2, color)
            end
        end
        
        local text = {
            "Click or Hold Left mouse button to update the ClientActor's target",
            "Click or Hold Right mouse button to spawn and move around a ClientActor"
        }
        local textSize = TextSize.VeryLarge
        local centerX = Render.Width / 2
        local y = Render.Height * 0.25
        
        for _, v in pairs(text) do
            local pos = Vector2(centerX - (Render:GetTextWidth(v, textSize) / 2), y)
            Render:DrawText(pos + Vector2.One, v, Color.Black, textSize)
            Render:DrawText(pos, v, Color.Yellow, textSize)
            
            y = y + Render:GetTextHeight(v, textSize)
        end
    end
)
