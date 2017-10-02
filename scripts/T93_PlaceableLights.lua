-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --
-- PlaceableLights
--
-- Purpose: Adding functionality to placeable lights
-- 
-- Authors: Timmiej93
--
-- Copyright (c) Timmiej93, 2017
-- For more information on copyright for this mod, please check the readme file on Github
--
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --


PlaceableLights = {};
PlaceableLights_mt = Class(PlaceableLights, Placeable);
InitObjectClass(PlaceableLights, "PlaceableLights");
registerPlaceableType("placeableLights", PlaceableLights);


-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --
-- ^
-- | Load PlaceableLights table, required for loading other files
-- 
-- | Load files
-- v
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --


local modDir = g_currentModDirectory;
local files = {
    'Events', 
    'LampFunctions',
    'PlacementScreenFunctions'
};

for _,file in pairs(files) do
    local filePath = string.format("%sscripts/T93_PLP_%s.lua", modDir, file);

    assert(fileExists(filePath), "\tERROR: Could not load file \""..filePath.."\"");
    source(filePath);
end;


-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --
-- ^
-- | Load files
-- 
-- | Manager
-- v
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --


PlaceableLightsManager = {}
PlaceableLightsManager.alignToGround = true;
PlaceableLightsManager.modName = g_currentModName;
PlaceableLightsManager.placeableObjectEnvironment = nil
PlaceableLightsManager.currentGhostHeight = 0

function PlaceableLightsManager:loadMap(name)
    g_currentMission.PlaceableLightsManager = PlaceableLightsManager
end;

function PlaceableLightsManager:deleteMap()end;
function PlaceableLightsManager:keyEvent(unicode, sym, modifier, isDown)end;
function PlaceableLightsManager:mouseEvent(posX, posY, isDown, isUp, button)end;
function PlaceableLightsManager:update(dt)end;
function PlaceableLightsManager:draw()end;

addModEventListener(PlaceableLightsManager);


-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --
-- ^
-- | Manager
-- 
-- | Lamp
-- v
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --


function PlaceableLights:new()
    local self = Placeable:new(g_server ~= nil, g_client ~= nil, PlaceableLights_mt);
    registerObjectClassName(self, "PlaceableLights");
    return self;
end;

function PlaceableLights:load(xmlFilename, x,y,z, rx,ry,rz, initRandom)
    if not PlaceableLights:superClass().load(self, xmlFilename, x,y,z, rx,ry,rz, initRandom) then
        return false;
    end

    self.xmlFile = loadXMLFile("TempXML", xmlFilename);
    if self.xmlFile == 0 or self.xmlFile == nil then
    	print("XML file not found!")
    end

    -- Priority
    self.priorities = {};

    -- Two second timer
    self.timer2sec = 0;
    self.timer2secActive = false;

    -- Light staes
    self.lightStates = {
        [1] = g_i18n:getText("button_lightBehavior_automatic"),
        [2] = g_i18n:getText("button_lightBehavior_alwaysOn"),
        [3] = g_i18n:getText("button_lightBehavior_alwaysOff")
    }
    self.light = Utils.indexToObject(self.nodeId, Utils.getNoNil(getUserAttribute(self.nodeId, "lighting"), 0));
	self.currentLightState = 1;

    -- Trigger
    self.playerTrigger = Utils.indexToObject(self.nodeId, Utils.getNoNil(getUserAttribute(self.nodeId, "playerTrigger"), 1));
    self.playerInTrigger = false;

    -- Height/rotation alterations
    self.alignmentGuide = Utils.indexToObject(self.nodeId, getUserAttribute(self.nodeId, "alignmentGuide"));
	self.raisableElement = Utils.indexToObject(self.nodeId, getUserAttribute(self.nodeId, "variableHeight"));
	self.rotateableElement = Utils.indexToObject(self.nodeId, getUserAttribute(self.nodeId, "variableRotation"));

    if self.xmlFile ~= 0 and self.xmlFile ~= nil then
    	if self.alignmentGuide ~= nil and self.raisableElement then
	    	local coarseHeight = Utils.getNoNil(getXMLFloat(self.xmlFile, "placeable.placeableLight.height#coarseHeightChange"), 1);
	    	local fineHeight = Utils.getNoNil(getXMLFloat(self.xmlFile, "placeable.placeableLight.height#fineHeightChange"), 0.1);
	    	local ultraFineHeight = Utils.getNoNil(getXMLFloat(self.xmlFile, "placeable.placeableLight.height#ultraFineHeightChange"), 0.01);
	    	
	    	if coarseHeight == nil or fineHeight == nil or ultraFineHeight == nil then
	    		print("ERROR: There was an issue with loading data from the XML file!")
	    		return false;
	    	else
	    		self.adjustHeights = {};
	    		self.adjustHeights[1] = {["height"] = coarseHeight, ["text"] = g_i18n:getText("button_height_changeStepSize_Coarse")}
	    		self.adjustHeights[2] = {["height"] = fineHeight, ["text"] = g_i18n:getText("button_height_changeStepSize_Fine")}
	    		self.adjustHeights[3] = {["height"] = ultraFineHeight, ["text"] = g_i18n:getText("button_height_changeStepSize_UltraFine")}
	    		self.activeHeight = 1;
	    	end
	    end

    	if self.rotateableElement ~= nil then
    		local rotationCoarse = Utils.getNoNil(getXMLFloat(self.xmlFile, "placeable.placeableLight.rotation#coarse"), 22.5)
	    	local rotationFine = Utils.getNoNil(getXMLFloat(self.xmlFile, "placeable.placeableLight.rotation#fine"), 10);
	    	local rotationUltraFine = Utils.getNoNil(getXMLFloat(self.xmlFile, "placeable.placeableLight.rotation#ultraFine"), 1);

	    	if rotationCoarse == nil or rotationFine == nil or rotationUltraFine == nil then
	    		print("ERROR: There was an issue with loading data from the XML file!")
	    		return false;
	    	else
	    		self.adjustRotations = {};
	    		self.adjustRotations[1] = {["rotation"] = rotationCoarse, ["text"] = g_i18n:getText("button_height_changeStepSize_Coarse")}
	    		self.adjustRotations[2] = {["rotation"] = rotationFine, ["text"] = g_i18n:getText("button_height_changeStepSize_Fine")}
	    		self.adjustRotations[3] = {["rotation"] = rotationUltraFine, ["text"] = g_i18n:getText("button_height_changeStepSize_UltraFine")}
	    		self.activeRotation = 1;
	    	end
	    end
	else
		print("ERROR: There was an issue loading the XML file!")
    end



    -- Color variations
    local whiteLight = Utils.indexToObject(self.nodeId, getUserAttribute(self.nodeId, "lightingWhite"));
    local orangeLight = Utils.indexToObject(self.nodeId, getUserAttribute(self.nodeId, "lightingOrange"));

    self.lightColors = {
        [1] = {["text"] = g_i18n:getText("button_changeColor_white"), ["lightElement"] = whiteLight},
        [2] = {["text"] = g_i18n:getText("button_changeColor_orange"), ["lightElement"] = orangeLight},
    }
    self.activeLightColor = 1;

    for _,light in pairs(self.lightColors) do
        light.lightSource = getChild(light.lightElement, "lightSource");
        light.corona = getChild(light.lightElement, "corona")
    end

	self.currentBrightness = getLightRange(self.lightColors[1].lightSource);

    if PlaceableLightsManager.ghost == nil and g_gui.currentGui == (g_gui.guis.PlacementScreen or g_gui.guis.ShopScreen) then
        PlaceableLightsManager.ghost = self;
    end

    self.locked = true;
    self.lockStates = {
    	[true] = {["text"] = g_i18n:getText("button_lockState_locked")},
    	[false] = {["text"] = g_i18n:getText("button_lockState_unlocked")}
	}

    return true;
end

function PlaceableLights:finalizePlacement()
    PlaceableLights:superClass().finalizePlacement(self);
    g_currentMission.environment:addWeatherChangeListener(self);

    if self.playerTrigger ~= nil then
        addTrigger(self.playerTrigger, "PlayerTriggerCallback", self);
    end

    if self.alignmentGuide ~= nil then
    	setVisibility(self.alignmentGuide, false);
    end

    for _,light in pairs(self.lightColors) do
    	if light.corona ~= 0 and light.corona ~= nil then
    		setVisibility(light.corona, true);
    	end
    end

    if PlaceableLightsManager.currentGhostHeight ~= nil and PlaceableLightsManager.currentGhostHeight ~= 0 and self.raisableElement ~= nil then
        local x,_,z = getTranslation(self.raisableElement)
        setTranslation(self.raisableElement, x, PlaceableLightsManager.currentGhostHeight, z)
    end

    self:setLightState();
    self:setLightColor();
end

function PlaceableLights:delete()
    if self.playerTrigger ~= nil then
        removeTrigger(self.playerTrigger)
    end

    if PlaceableLightsManager.ghost ~= nil then
        PlaceableLightsManager.ghost = nil
    end

    if g_currentMission.environment ~= nil then
        g_currentMission.environment:removeWeatherChangeListener(self);
    end;

	unregisterObjectClassName(self);
    PlaceableLights:superClass().delete(self);
end;

function PlaceableLights:deleteExtra()
    if PlaceableLightsManager.ghost ~= nil then
        PlaceableLightsManager.ghost = nil;
    end

    PlaceableLightsManager.currentGhostHeight = 0;
end
g_gui.guis.PlacementScreen.onCloseCallback = Utils.appendedFunction(g_gui.guis.PlacementScreen.onCloseCallback, PlaceableLights.deleteExtra)


function PlaceableLights:weatherChanged()
    if self.currentLightState == 1 and g_currentMission ~= nil and g_currentMission.environment ~= nil then
        setVisibility(self.light, not (g_currentMission.environment.isSunOn and g_currentMission.environment.currentRain == nil));
    end;
end;

function PlaceableLights:activateTimer()
    -- Enable light for two seconds, override other controls
    self.timer2secActive = true;
    self.timer2sec = 0;
    setVisibility(self.light, true);
end

function PlaceableLights:update(dt)
    local function getPriority(basePrio)
        if type(basePrio) ~= "number" then
            print("prio not a number!")
            return
        end

        if self.priorities[basePrio] == nil then
            self.priorities[basePrio] = {}
        end

        table.insert(self.priorities[basePrio], true)
        return basePrio + (#(self.priorities[basePrio])/1000)
    end

    -- Two second timer
    if self.timer2secActive then
        if self.timer2sec < 2000 then
            self.timer2sec = self.timer2sec + dt;
            self.timer2secThrough = false;
        else
            self.timer2sec = 0;
            self.timer2secThrough = true;
            self.timer2secActive = false;
        end;
    end

    if self.timer2secThrough then
        self.timer2secThrough = false;
        self:setLightState();
    end

    -- When player is in trigger
    if self.playerInTrigger then

        if g_currentMission:getIsServer() or g_currentMission.isMasterUser then

            if g_gui.currentGui ~= nil then
                self.chatDialogOpen = (g_gui.currentGui.name == "ChatDialog");
            else
                self.chatDialogOpen = false;
            end

            -- Change light lock state
            local lockStateText = self.lockStates[self.locked].text;
            g_currentMission:addHelpButtonText(string.format(g_i18n:getText("button_changeLockState"), lockStateText), InputBinding.changeLockState, nil, getPriority(0));
            if InputBinding.hasEvent(InputBinding.changeLockState) then
            	self.locked = not self.locked;
            end

            if self.locked then
            	return;
            end

            if self.rotateableElement ~= nil and self.adjustRotations ~= nil then

    	        -- -- Change lamp rotation
    	        g_currentMission:addHelpButtonText(g_i18n:getText("button_changeRotation"), InputBinding.changeRotationF1, nil, getPriority(0));
    	        if InputBinding.hasEvent(InputBinding.changeRotationRight) and not self.chatDialogOpen then
    	            self:rotateLight(true)
    	        elseif InputBinding.hasEvent(InputBinding.changeRotationLeft) and not self.chatDialogOpen then
    	            self:rotateLight(false)
    	        end
    	        
    	        -- -- Change light rotation increment
    	        local parenthesisTextRotation = self.adjustRotations[self.activeRotation].text;
    	        local rotation = string.format("%.1f", self.adjustRotations[self.activeRotation].rotation);
    	        g_currentMission:addHelpButtonText(string.format(g_i18n:getText("button_rotation_changeStepSize"), parenthesisTextRotation, rotation), InputBinding.changeRotationStepSize, nil, getPriority(0));
    	    	if InputBinding.hasEvent(InputBinding.changeRotationStepSize) then
                    self:changeRotationIncrement()
    	        end
    	    end

            if self.alignmentGuide ~= nil and self.raisableElement ~= nil and self.adjustHeights ~= nil then

                -- -- Change lamp height
                g_currentMission:addHelpButtonText(g_i18n:getText("button_changeHeight"), InputBinding.changeHeightF1, nil, getPriority(0));
                if InputBinding.hasEvent(InputBinding.changeHeightUp) and not self.chatDialogOpen then
                    self:changeHeight(true)
                elseif InputBinding.hasEvent(InputBinding.changeHeightDown) and not self.chatDialogOpen then
                    self:changeHeight(false)
                end

                -- -- Change lamp height increment
                local parenthesisText = self.adjustHeights[self.activeHeight].text;
                local height = string.format("%.2f", self.adjustHeights[self.activeHeight].height);
                g_currentMission:addHelpButtonText(string.format(g_i18n:getText("button_height_changeStepSize"), parenthesisText, height), InputBinding.changeStepSize, nil, getPriority(0));
                if InputBinding.hasEvent(InputBinding.changeStepSize) and not self.chatDialogOpen then
                    self:changeHeightIncrement()
                end
    	    end

        	-- Change light behavior
            g_currentMission:addHelpButtonText(string.format(g_i18n:getText("button_lightBehavior"), self.lightStates[self.currentLightState]), InputBinding.changeLightBehavior, nil, getPriority(0));
            if InputBinding.hasEvent(InputBinding.changeLightBehavior) and not self.chatDialogOpen then
                self:changeLightBehavior()
            end

            if self.lightColors ~= nil then

                -- Change lamp color
            	if self.activeLightColor ~= nil then
    		    	if self.lightColors ~= nil and self.lightColors[self.activeLightColor] ~= nil then
        		    	local text = Utils.getNoNil(self.lightColors[self.activeLightColor].text, "ERROR");
                        g_currentMission:addHelpButtonText(string.format(g_i18n:getText("button_changeColor"), text), InputBinding.changeLightColor, nil, getPriority(0));
        				if InputBinding.hasEvent(InputBinding.changeLightColor) and not self.chatDialogOpen then
                            self:changeLightColor()
    			        end
    			    end
    			end

                -- Change lamp brightness
                if self.currentBrightness ~= nil then
    	            g_currentMission:addHelpButtonText(string.format(g_i18n:getText("button_changeBrightness"), Utils.getNoNil(self.currentBrightness, 0)), InputBinding.changeBrightnessF1, nil, getPriority(0));
    	            if InputBinding.hasEvent(InputBinding.changeBrightnessUp) and not self.chatDialogOpen then
                    	self:changeBrightness(true)
    	            elseif InputBinding.hasEvent(InputBinding.changeBrightnessDown) and not self.chatDialogOpen then
                    	self:changeBrightness(false)
    	            end
    	        end
            end
            self.priorities = {};
        else

            g_currentMission:addExtraPrintText(g_i18n:getText("require_admin_rights"))
        end
    end
end;

function PlaceableLights:PlayerTriggerCallback(triggerId, otherId, onEnter, onLeave, onStay)
	if (g_currentMission.player and otherId == g_currentMission.player.rootNode) then
	    if onEnter then
	        self.playerInTrigger = true;
	    elseif onLeave then
	        self.playerInTrigger = false;
	    end
    end
end


-- LOAD/SAVE
function PlaceableLights:getSaveAttributesAndNodes(nodeIdent)
    local attributes, nodes = PlaceableLights:superClass().getSaveAttributesAndNodes(self, nodeIdent);
    nodes = nodes..nodeIdent..	"<lightData locked=\""..tostring(self.locked)..
                                    "\" currentLightState=\""..self.currentLightState..
			    					"\" activeLightColor=\""..self.activeLightColor..
			                        "\" currentBrightness=\""..self.currentBrightness

    if self.raisableElement ~= nil and self.activeHeight ~= nil then
    	local _,y,_ = getTranslation(self.raisableElement);
    	nodes = nodes..			"\" activeHeight=\""..self.activeHeight..
								"\" height=\""..y
    end

    if self.rotateableElement ~= nil and self.activeRotation ~= nil then
    	local _,rY,_ = getRotation(self.rotateableElement);
    	nodes = nodes..			"\" activeRotation=\""..self.activeRotation..
    							"\" rotation=\""..rY
	end

    nodes = nodes..             "\"/>"

    return attributes, nodes;
end;

function PlaceableLights:loadFromAttributesAndNodes(xmlFile, key, resetVehicles)
	local x,y,z = Utils.getVectorFromString(getXMLString(xmlFile, key.."#position"));
    local xRot,yRot,zRot = Utils.getVectorFromString(getXMLString(xmlFile, key.."#rotation"));
    if x == nil or y == nil or z == nil or xRot == nil or yRot == nil or zRot == nil then
        return false;
    end;
    local xmlFilename = getXMLString(xmlFile, key.."#filename");
    if xmlFilename == nil then
        return false;
    end;
    xmlFilename = Utils.convertFromNetworkFilename(xmlFilename);
    
    local locked = getXMLBool(xmlFile, key..".lightData(0)#locked");
    local lightState = getXMLInt(xmlFile, key..".lightData(0)#currentLightState");
    local lightColor = getXMLInt(xmlFile, key..".lightData(0)#activeLightColor");
    local brightness = getXMLInt(xmlFile, key..".lightData(0)#currentBrightness");
    local activeHeight = getXMLInt(xmlFile, key..".lightData(0)#activeHeight");
    local yRaised = getXMLFloat(xmlFile, key..".lightData(0)#height");
    local yRotated = getXMLFloat(xmlFile, key..".lightData(0)#rotation");

    if self:load(xmlFilename, x,y,z, xRot, yRot, zRot, false, false) then
        self.age = Utils.getNoNil(getXMLFloat(xmlFile, key.."#age"), 0);
        self.price = Utils.getNoNil(getXMLInt(xmlFile, key.."#price"), self.price);
        self.isLoadedFromSavegame = true;
        self.locked = Utils.getNoNil(locked, self.locked);
        self.currentLightState = Utils.getNoNil(lightState, self.currentLightState);
        self.activeLightColor = Utils.getNoNil(lightColor, self.activeLightColor);
        self.currentBrightness = Utils.getNoNil(brightness, self.currentBrightness);
        self.activeHeight = activeHeight; -- Can be nil, for lights without height adjustment
        if self.raisableElement ~= nil then
            yRaised = Utils.getNoNil(yRaised, 0)
        	setTranslation(self.raisableElement, 0,yRaised,0);
        end
        if self.rotateableElement ~= nil then
            yRotated = Utils.getNoNil(yRotated, 0)
        	setRotation(self.rotateableElement, 0,yRotated,0)
        end
        self:finalizePlacement();

        return true;
    else
        return false;
    end;
end;

function PlaceableLights:readStream(streamId, connection)
	PlaceableLights:superClass().readStream(self, streamId, connection);

    self.currentLightState = Utils.getNoNil(streamReadInt8(streamId), self.currentLightState)
    self.activeLightColor = Utils.getNoNil(streamReadInt8(streamId), self.activeLightColor)
    self.currentBrightness = Utils.getNoNil(streamReadInt8(streamId), self.changeBrightness)

    local y = streamReadFloat32(streamId)
    local rY = streamReadFloat32(streamId)

    self:setLightState();
    self:setLightColor();

    if self.lightColors ~= nil then
        for _,light in pairs(self.lightColors) do
            setLightRange(light.lightSource, self.currentBrightness)
        end
    end

    if y ~= nil and y ~= -9999 then
        setTranslation(self.raisableElement, 0,y,0);
    end

    if rY ~= nil and rY ~= -9999 then
        setRotation(self.rotateableElement, 0,rY, 0);
    end
end

function PlaceableLights:writeStream(streamId, connection)
    PlaceableLights:superClass().writeStream(self, streamId, connection);

    local y = -9999
    if self.raisableElement ~= nil then
        _,y,_ = getTranslation(self.raisableElement);
    end

    local rY = -9999
    if self.rotateableElement ~= nil then
        _,rY,_ = getRotation(self.rotateableElement);
    end

    streamWriteInt8(streamId, self.currentLightState);
    streamWriteInt8(streamId, self.activeLightColor);
    streamWriteInt8(streamId, self.currentBrightness);

    streamWriteFloat32(streamId, y)
    streamWriteFloat32(streamId, rY)
end