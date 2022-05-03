local Windows = GameMain:GetMod("Windows");
local OperationMenuWindow = Windows:CreateWindow("MultiOperationHelper_OperationMenuWindow");

function OperationMenuWindow:OnInit()
	self.window.contentPane = CS.FairyGUI.UIPackage.CreateObject("MultiOperationHelper", "OperationMenuWindow");--载入UI包里的窗口
	self.list = self:GetChild("list");
	self.list.onClickItem:Add(self.ListClickItem);
	self.inited = true;
	--print("OperationMenuWindow OnInit");
end

function OperationMenuWindow:ShowMenu(thing, menu, callBack)
	self.thing = thing;
	self.menu = menu;
	self.callBack = callBack;
	if self.window.isShowing then
		self:OnShowUpdate();
	else
		self:Show();
	end
end

function OperationMenuWindow:OnShowUpdate()
	self.window:BringToFront();
	self.list:RemoveChildrenToPool();
	for _, memu_item in pairs(self.menu) do
		local button = self.list:AddItemFromPool();
		local bg = button:GetController("bg");
		bg.selectedIndex = memu_item.bg or 0;
		button.title = memu_item.dspName;
		button.icon = memu_item.icon;
		button.data = memu_item.data;
		button.tooltips = memu_item.tooltips;
		button.grayed = memu_item.grayed;
	end
	CS.FairyGUI.GRoot.inst:ShowPopup(self.window.contentPane);  --Wnd_SelectThing.OnShowUpdate()
	self.window.contentPane.onRemovedFromStage:Add(self.HideMenu);
end

function OperationMenuWindow:ClickBtn(context)
	local button = context.data;
	if not button.grayed then
		self.callBack(self.thing, button.data)
	end
	CS.FairyGUI.GRoot.inst:HidePopup(self.window.contentPane);
end

function OperationMenuWindow:OnHide()
	self.list:RemoveChildrenToPool();
	self.thing = nil;
	self.menu = nil;
	self.callBack = nil;
	--print("OperationMenuWindow OnHide");
end

function OperationMenuWindow:RemoveCallback()
	if self.inited then
		self.list.onClickItem:Clear();
		self.window.contentPane.onRemovedFromStage:Clear();
	end
end

function OperationMenuWindow.ListClickItem(context)
	OperationMenuWindow:ClickBtn(context);
end

function OperationMenuWindow.HideMenu()
	OperationMenuWindow.window:Hide();
end