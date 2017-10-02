-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --
-- PlaceableLights
--
-- Purpose: Adding functionality to placeable lights
--              Functions managing special placement functionality
-- 
-- Authors: Timmiej93
--
-- Copyright (c) Timmiej93, 2017
-- For more information on copyright for this mod, please check the readme file on Github
--
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --

function PlaceableLights:PS_isInsideRestrictedZone(superFunc, ...)

    -- if g_gui.currentGui.target.placementItem.customEnvironment == PlaceableLightsManager.modName and t93Settings.freePlacement then
    local PLM = g_currentMission.PlaceableLightsManager;
    if PLM.placeableObjectEnvironment ~= nil and PLM.placeableObjectEnvironment == PLM.modName then
        return false
    end

    return superFunc(self, ...);
end
PlacementScreen.isInsideRestrictedZone = Utils.overwrittenFunction(PlacementScreen.isInsideRestrictedZone, PlaceableLights.PS_isInsideRestrictedZone)

function PlaceableLights:PS_hasObjectOverlap(superFunc, ...)

    -- if g_gui.currentGui.target.placementItem.customEnvironment == PlaceableLightsManager.modName and t93Settings.freePlacement then
    local PLM = g_currentMission.PlaceableLightsManager;
    if PLM.placeableObjectEnvironment ~= nil and PLM.placeableObjectEnvironment == PLM.modName then
        return false
    end

    return superFunc(self, ...);
end
PlacementScreen.hasObjectOverlap = Utils.overwrittenFunction(PlacementScreen.hasObjectOverlap, PlaceableLights.PS_hasObjectOverlap)

function PlaceableLights:PS_placementRaycastCallback(superFunc, terrainId1, x,y,z, a,b,c,d,e, terrainId2)

    -- if g_gui.currentGui.target.placementItem.customEnvironment == PlaceableLightsManager.modName and t93Settings.freePlacement then 
    local PLM = g_currentMission.PlaceableLightsManager;
    if PLM.placeableObjectEnvironment ~= nil and PLM.placeableObjectEnvironment == PLM.modName then
        if not PlaceableLightsManager.alignToGround then
            return superFunc(self, g_currentMission.terrainRootNode, x,y,z, a,b,c,d,e, g_currentMission.terrainRootNode)
        else
            local terrainHeight = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x,y,z)
            return superFunc(self, g_currentMission.terrainRootNode, x,terrainHeight,z, a,b,c,d,e, g_currentMission.terrainRootNode)
        end
    end

    return superFunc(self, terrainId1, x,y,z, a,b,c,d,e, terrainId2);
end
PlacementScreen.placementRaycastCallback = Utils.overwrittenFunction(PlacementScreen.placementRaycastCallback, PlaceableLights.PS_placementRaycastCallback)

function PlaceableLights:PSUpdate(dt)

    if g_gui.currentGui ~= nil then
        if g_gui.currentGui.target.placementItem ~= nil then
            if g_gui.currentGui.target.placementItem.customEnvironment ~= nil then
                if g_gui.currentGui.target.placementItem.customEnvironment ~= g_currentMission.PlaceableLightsManager.placeableObjectEnvironment then
                    g_currentMission.PlaceableLightsManager.placeableObjectEnvironment = g_gui.currentGui.target.placementItem.customEnvironment
                    PlaceableLightsManagerEvent.sendEvent()
                end
            end
        end
    end

    local lamp = PlaceableLightsManager.ghost;

    if InputBinding.hasEvent(InputBinding.TOGGLE_HELP_TEXT) then
        g_gameSettings.showHelpMenu = (not g_gameSettings.showHelpMenu)
    end

    if lamp ~= nil then
        if lamp.alignmentGuide ~= nil and lamp.raisableElement ~= nil and lamp.adjustHeights ~= nil then

            -- Change lamp height increment
            local parenthesisText = lamp.adjustHeights[lamp.activeHeight].text;
            local height = string.format("%.2f", lamp.adjustHeights[lamp.activeHeight].height);
            g_currentMission:addHelpButtonText(string.format(g_i18n:getText("button_height_changeStepSize"), parenthesisText, height), InputBinding.changeStepSize);
            
            if InputBinding.hasEvent(InputBinding.changeStepSize) then
                lamp:changeHeightIncrement(true)
            end

            -- Change lamp height
            g_currentMission:addHelpButtonText(g_i18n:getText("button_changeHeight"), InputBinding.changeHeightF1);

            -- Change lamp height up/down
            if InputBinding.hasEvent(InputBinding.changeHeightUp) then
                lamp:changeHeight(true, true)
                PlaceableLightsManagerEvent.sendEvent()
            elseif InputBinding.hasEvent(InputBinding.changeHeightDown) then
                lamp:changeHeight(false, true)
                PlaceableLightsManagerEvent.sendEvent()
            end
        end

        local yesNoText = PlaceableLightsManager.alignToGround and g_i18n:getText("button_alignToGround_yes") or g_i18n:getText("button_alignToGround_no")
        g_currentMission:addHelpButtonText(string.format(g_i18n:getText("button_alignToGround"), yesNoText), InputBinding.HONK)
        if InputBinding.hasEvent(InputBinding.HONK) then
            PlaceableLightsManager.alignToGround = (not PlaceableLightsManager.alignToGround)
        end
    end
end
PlacementScreen.update = Utils.prependedFunction(PlacementScreen.update, PlaceableLights.PSUpdate)