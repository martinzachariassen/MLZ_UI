-- MLZ UI: Small UI building blocks for the wizard

local _, ns = ...

local W = {}
ns.W = W

function W.Text(parent, font, text, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(true)
    if text then fs:SetText(text) end
    return fs
end

function W.Button(parent, text, width, height, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width or 120, height or 24)
    b:SetText(text)
    if onClick then b:SetScript("OnClick", onClick) end
    return b
end

function W.Check(parent, label, onClick)
    local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    c:SetSize(24, 24)
    if label then
        c.label = W.Text(c, "GameFontNormal", label)
        c.label:SetPoint("LEFT", c, "RIGHT", 2, 0)
    end
    if onClick then c:SetScript("OnClick", function(self) onClick(self, self:GetChecked() and true or false) end) end
    return c
end

-- Scrollable list: a ScrollFrame with a content frame
function W.ScrollArea(parent)
    local sf = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    local content = CreateFrame("Frame", nil, sf)
    content:SetSize(1, 1)
    sf:SetScrollChild(content)
    sf:SetScript("OnSizeChanged", function(self, w) content:SetWidth(w) end)
    sf.content = content
    return sf
end

-- Tooltip helper
function W.Tooltip(frame, title, text)
    frame:SetScript("OnEnter", function(self)
        if not title and not text then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if title then GameTooltip:SetText(title, 1, 1, 1) end
        if text then GameTooltip:AddLine(text, nil, nil, nil, true) end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- Color codes
W.C = {
    gold = "|cffffd100", grey = "|cff808080", red = "|cffff5555", green = "|cff55ff55",
    blue = "|cff33ccff", white = "|cffffffff", r = "|r",
}
