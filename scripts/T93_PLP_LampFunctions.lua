-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --
-- PlaceableLights
--
-- Purpose: Adding functionality to placeable lights
--              Lamp functions
-- 
-- Authors: Timmiej93
--
-- Copyright (c) Timmiej93, 2017
-- For more information on copyright for this mod, please check the readme file on Github
--
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --

function PlaceableLights:rotateLight(right, noEventSend)

    local _,ry,_ = getRotation(self.rotateableElement);
    local dry = math.rad(self.adjustRotations[self.activeRotation].rotation)

	if right then
        ry = Utils.clamp(((ry-dry)%math.rad(360)), 0, 360)
    else
        ry = Utils.clamp(((ry+dry)%math.rad(360)), 0, 360)
    end

    local addToPhysicsCallback = self:prepareForMovement()
    setRotation(self.rotateableElement, 0,ry,0);
    addToPhysicsCallback()

    if not noEventSend then
        PlaceableLightsEvent.sendEvent(self);
    end
end

function PlaceableLights:changeRotationIncrement(noEventSend)

	self.activeRotation = self.activeRotation + 1;
    if self.activeRotation > table.getn(self.adjustRotations) then
        self.activeRotation = 1;
    end

    if not noEventSend then
        PlaceableLightsEvent.sendEvent(self);
    end
end

function PlaceableLights:changeHeight(up, noEventSend)

	local _,y,_ = getTranslation(self.raisableElement);
    local dy = self.adjustHeights[self.activeHeight].height;

	if up then
	    y = Utils.clamp(y+dy, -10, 50);
	else
	    y = Utils.clamp(y-dy, -10, 50)
	end

    local addToPhysicsCallback = self:prepareForMovement()
    PlaceableLightsManager.currentGhostHeight = y;
    setTranslation(self.raisableElement, 0,y,0);
    addToPhysicsCallback()

    if not noEventSend then
        PlaceableLightsEvent.sendEvent(self);
    end
end

function PlaceableLights:changeHeightIncrement(noEventSend)
	
	self.activeHeight = self.activeHeight + 1;
	if self.activeHeight > table.getn(self.adjustHeights) then
	    self.activeHeight = 1;
	end

    if not noEventSend then
        PlaceableLightsEvent.sendEvent(self);
    end
end

function PlaceableLights:changeLightBehavior(noEventSend)

	self.currentLightState = self.currentLightState + 1;
    if self.currentLightState > #(self.lightStates) then
        self.currentLightState = 1;
    end

    if not self.timer2secActive then
        self:setLightState();
    end

    if not noEventSend then
        PlaceableLightsEvent.sendEvent(self);
    end
end

function PlaceableLights:changeLightColor(noEventSend)

	self.activeLightColor = self.activeLightColor + 1;
	if self.activeLightColor > #(self.lightColors) then
	    self.activeLightColor = 1;
	end
	self:setLightColor();

    if not noEventSend then
        PlaceableLightsEvent.sendEvent(self);
    end
end

function PlaceableLights:changeBrightness(increase, noEventSend)
    
    local minLevel, maxLevel = 1, 50;

    if increase then
		self.currentBrightness = Utils.clamp(self.currentBrightness + 1, minLevel, maxLevel)
	else
		self.currentBrightness = Utils.clamp(self.currentBrightness - 1, minLevel, maxLevel)
	end

    for _,light in pairs(self.lightColors) do
        setLightRange(light.lightSource, self.currentBrightness);
    end
    self:activateTimer();

    if not noEventSend then
        PlaceableLightsEvent.sendEvent(self);
    end
end

function PlaceableLights:setLightState()
    if self.currentLightState == 1 then
        self:weatherChanged();
    elseif self.currentLightState == 2 then
        setVisibility(self.light, true);
    elseif self.currentLightState == 3 then
        setVisibility(self.light, false);
    end
end

function PlaceableLights:setLightColor()
    local found = false;
    for i,lightTable in pairs(self.lightColors) do
        if i == self.activeLightColor then
            setVisibility(lightTable.lightElement, true);
            found = true;
        else
            setVisibility(lightTable.lightElement, false);
        end
    end
    if not found then
        self.activeLightColor = 1;
        self:setLightColor();
    end
    self:activateTimer();
end

function PlaceableLights:prepareForMovement()

    if self.raisableElement ~= nil then
        removeFromPhysics(self.raisableElement)
    end
    if self.rotateableElement ~= nil then
        removeFromPhysics(self.rotateableElement)
    end

    local function revert()

        if self.raisableElement ~= nil then
            addToPhysics(self.raisableElement)
        end
        if self.rotateableElement ~= nil then
            addToPhysics(self.rotateableElement)
        end
    end

    return revert
end