local MultiOperationHelper = GameMain:NewMod("MultiOperationHelper");--先注册一个新的MOD模块

local SaveData = {};

function MultiOperationHelper:OnInit()
	self.mod_enable = true;
	self.refining_fabao_table = SaveData.refining_fabao or {};
	self.last_selected_thing = nil;
--[[
	self.config = SaveData.config or {};
	for _, config_data in pairs(self.configItems) do
		if self.config[config_data.name] == nil then
			self.config[config_data.name] = config_data.default;
		end
	end
]]--
	--print("MultiOperationHelper OnInit");
end

function MultiOperationHelper:OnEnter()
	if not self:CheckModLegal() or CS.XiaWorld.World.Instance.GameMode == CS.XiaWorld.g_emGameMode.Fight then
		self.mod_enable = false;
		return;
	end	
	local Windows = GameMain:GetMod("Windows");
	self.OperationMsgWindow = Windows:GetWindow("OperationMsgWindow");
	self.MultiSelectWindow = Windows:GetWindow("MultiSelectWindow");
	self.NumberSettingWindow = Windows:GetWindow("NumberSettingWindow");
	self.OperationMenuWindow = Windows:GetWindow("OperationMenuWindow");
	self.MultiFuPainterWindow = Windows:GetWindow("MultiFuPainterWindow");

	self.OperationMsgWindow:Init();
	self.MultiSelectWindow:Init();
	self.NumberSettingWindow:Init();
	self.OperationMenuWindow:Init();
	self.MultiFuPainterWindow:Init();
	
	local Event = GameMain:GetMod("_Event");
	local g_emEvent = CS.XiaWorld.g_emEvent;
	Event:RegisterEvent(g_emEvent.SelectItem,  function(evt, item, objs) 
		self:AddBtn2Item(evt, item, objs); 
	end, "AddBtn2Item");
	Event:RegisterEvent(g_emEvent.SelectNpc,  function(evt, npc, objs) 
		self:AddBtn2Npc(evt, npc, objs);
	end, "AddBtn2Npc");
	Event:RegisterEvent(g_emEvent.WindowEvent, function(evt, thing, objs) 
		self:AddStorageMenu(evt, thing, objs); 
	end, "AddStorageMenu");
	print("MultiOperationHelper Enter");
end

function MultiOperationHelper:AddBtn2Item(evt, thing, objs)  --向Item添加按键
	--print(thing);
	if thing == nil or thing == self.last_selected_thing or not self.mod_enable then
		return;
	end
	self.last_selected_thing = thing;
	self:RemoveBtn(thing);
	if thing.IsValid and (self:CanBePaint(thing) or self:CanBeEat(thing) or self:CanBeEquipt(thing) or self:CanBePut(thing)) then
		self:AddBtn(thing, self.operationDef.itemOperation);
	end
end

function MultiOperationHelper:AddBtn2Npc(evt, npc, objs)  --向NPC添加按键
	--print(npc);
	if npc == nil or not self.mod_enable then
		return;
	end
	self.last_selected_thing = npc;
	self:RemoveBtn(npc);
	if self:CanMultiRefining(npc) or self:CanMultiMagic(npc) then
		self:AddBtn(npc, self.operationDef.npcOperation);
	end
	self:InterruptGetFun(npc);
	if self.OperationMenuWindow.window.isShowing then  --通过数字键切换npc隐藏菜单
		CS.FairyGUI.GRoot.inst:HidePopup(self.OperationMenuWindow.window.contentPane);
	end
end

function MultiOperationHelper:AddBtn(thing, opt)
	thing:AddBtnData(opt.dspName, opt.icon, self:GetBtnLua(opt.data, opt.dspName), opt.tooltips, nil);
end

function MultiOperationHelper:GetBtnLua(func_name, btn_name)  --点击按键时执行的lua
--[[
	return string.format(
		"local mod = GameMain:GetMod('MultiOperationHelper'); "..
		"if mod['%s'] ~= nil then "..
			"mod:%s(bind); "..
		"else "..
			"bind:RemoveBtnData('%s'); "..
		"end", func_name, func_name, btn_name);
]]--
	return string.format("GameMain:GetMod('MultiOperationHelper'):%s(bind);", func_name);
end

function MultiOperationHelper:AddStorageMenu(evt, thing, objs)  --乾坤界添加右键菜单
	local Event = GameMain:GetMod("_Event");
	if not self.mod_enable then
		Event:UnRegisterEvent(g_emEvent.WindowEvent, "AddStorageMenu");
		return;
	end
	local window = objs[0];  --CS.Wnd_RemoteStorage.Instance
	if window ~= nil and window:GetType() == typeof(CS.Wnd_RemoteStorage) and window.contentPane ~= nil and window.contentPane.m_n5 ~= nil then
		window.contentPane.m_n5.onRightClickItem:Add(ShowStorageMenu);
		Event:UnRegisterEvent(g_emEvent.WindowEvent, "AddStorageMenu");
	end
end

function ShowStorageMenu(context)
	if not CS.UnityEngine.Input.GetKey(CS.UnityEngine.KeyCode.LeftControl) then
		return;
	end
	xlua.private_accessible(CS.XiaWorld.RemoteStorage);
	local item_name = context.data.data;
	--local item = CS.XiaWorld.World.Instance.map.SpaceRing:FindItem(item_name, nil, 0, 9999, nil);  --xlua.private_accessible(CS.XiaWorld.RemoteStorage)会导致FindItem出错
	local re, id = CS.XiaWorld.World.Instance.map.SpaceRing.StorageItem:TryGetValue(item_name);
	if id ~= nil then
		local item = CS.XiaWorld.ThingMgr.Instance:FindThingByID(id);
		if item ~= nil then
			MultiOperationHelper:ShowItemMenu(item);
		end
	end
end
		
function MultiOperationHelper:ShowItemMenu(item)  --显示物品操作菜单
	if not self.mod_enable then
		return;
	end
	local menu = {};
	if self:CanBePaint(item) then
		table.insert(menu, self.operationDef.multiFuPainter);
	end
	if self:CanBeEat(item) then
		table.insert(menu, self.operationDef.multiEatItem);
	end
	if self:CanBeEquipt(item) then
		table.insert(menu, self.operationDef.multiEquiptItem);
	end	
	if self:CanBePut(item) then
		table.insert(menu, self.operationDef.multiPutItem);
	end
	if #menu > 0 then
		self.OperationMenuWindow:ShowMenu(item, menu, function(item, data) self:DoMultiOperation(item, data); end);
	end
end

function MultiOperationHelper:ShowNpcMenu(npc)  --显示npc操作菜单
	if not self.mod_enable then
		return;
	end
	local menu = {};
	if self:CanMultiRefining(npc) then
		table.insert(menu, self:MultiRefiningFabaoBtn(npc));
	end
	if self:CanMultiMagic(npc) then
		for _, btn in pairs(self:MagicBtns(npc)) do
			table.insert(menu, btn);
		end
	end		
	if #menu > 0 then
		self.OperationMenuWindow:ShowMenu(npc, menu, function(npc, data) self:DoMultiOperation(npc, data); end);
	end
end

function MultiOperationHelper:MultiRefiningFabaoBtn(npc)  --添加‘批量炼宝’或‘取消批量炼宝’按键
	if self.refining_fabao_table ~= nil and self.refining_fabao_table[npc.ID] ~= nil and #self.refining_fabao_table[npc.ID] > 0 then
		local txt = self.operationDef.cancelRefiningFabao.tooltips
		txt = txt..string.format("\n\n剩余炼宝任务：%d", #self.refining_fabao_table[npc.ID]);
		if npc:CheckCommandSingle("RefiningFabao", false) == nil then
			local item = CS.XiaWorld.ThingMgr.Instance:FindThingByID(self.refining_fabao_table[npc.ID][1]);
			if item ~= nil and npc.LingV < item.Rate * item.Rate * 500 then
				txt = txt..string.format("\n[color=#FF0000]灵气不足：%d[/color]", item.Rate * item.Rate * 500);
			end
		end
		local btn = {};
		for k, v in pairs(self.operationDef.cancelRefiningFabao) do
			btn[k] = v;
		end
		btn.tooltips = txt;
		return btn;
	else
		return self.operationDef.multiRefiningFabao;
	end
end

function MultiOperationHelper:MagicBtns(npc)
	local btn_list = {}
	for _, magic in pairs(self.magic_name_list) do  --Panel_ThingInfo.UpdateBnts()
		if npc.PropertyMgr.Practice.Magics:Contains(magic) then
			local magic_def = CS.XiaWorld.PracticeMgr.Instance:GetMagicDef(magic);
			if magic_def ~= nil then
				local flag = false;
				local magic_btn = {};
				magic_btn.dspName = magic_def.DisplayName;
				magic_btn.icon = magic_def.Icon;
				magic_btn.data = magic_def.Name;
				magic_btn.tooltips = magic_def.Desc;
				magic_btn.bg = 1;
				local text = "";
				if magic_def.CostLing > 0 then
					local str = string.format("\n灵气：%.0f(%.0f)", magic_def.CostLing, npc.LingV);
					if magic_def.CostLing > npc.LingV then
						str = "[color=#FF0000]"..str.."[/color]";
						flag = true;
					end
					text = text..str;
				end
				if magic_def.CostAge > 0 then
					local str = string.format("\n寿元：%.0f(%.0f)", magic_def.CostAge, npc.MaxAge - npc.Age);
					if magic_def.CostAge > npc.MaxAge - npc.Age then
						str = "[color=#FF0000]"..str.."[/color]";
						flag = true;
					end
					text = text..str;
				end
				if magic_def.ItemCost ~= nil and magic_def.ItemCost.Count > 0 then
					for _, item_data in pairs(magic_def.ItemCost) do
						local item = CS.XiaWorld.ThingMgr.Instance:GetDef(CS.XiaWorld.g_emThingType.Item, item_data.name);
						local count = CS.XiaWorld.World.Instance.Warehouse:GetItemCount(item_data.name);
						local str = string.format("\n%s：%d/%d", item.ThingName, item_data.count, count);
						if item_data.count > count then
							str = "[color=#FF0000]"..str.."[/color]";
							flag = true;
						end
						text = text..str;
					end
				end
				if magic_def.CostGong > 0 then
					local str = string.format("\n修为：%.0f(%.0f)", magic_def.CostGong, npc.PropertyMgr.Practice.StageValue);
					if magic_def.CostGong > npc.PropertyMgr.Practice.StageValue then
						str = "[color=#FF0000]"..str.."[/color]";
						flag = true;
					end
					text = text..str;
				end
				if text ~= "" then
					magic_btn.tooltips = magic_btn.tooltips.."\n"..text;
				end
				magic_btn.grayed = flag;
				table.insert(btn_list, magic_btn);
			end
		end
	end
	local cmd_list = self:CheckMagicCommand(npc);
	if #cmd_list > 0 then
		local magic_btn = {};  --添加取消全部神通
		magic_btn.dspName = "取消全部神通";
		magic_btn.icon = "res/Sprs/ui/icon_lingxi01";
		magic_btn.data = "CancelMagicAll";
		magic_btn.tooltips = "取消该NPC所有批量施展的神通。\n";
		magic_btn.bg = 1;
		magic_btn.grayed = false;
		for _, magic in pairs(self.magic_name_list) do
			local magic_def = CS.XiaWorld.PracticeMgr.Instance:GetMagicDef(magic);
			local name = magic_def.DisplayName;
			local num = 0;
			for _, cmd in pairs(cmd_list) do
				if cmd.WorkParam3 == magic then
					num = num + 1;
				end
			end
			if num > 0 then
				magic_btn.tooltips = magic_btn.tooltips..string.format("\n%s：%d", name, num);
			end
		end
		table.insert(btn_list, magic_btn);
	end
	return btn_list;
end

function MultiOperationHelper:CanBeEat(thing)  --可以被小人食用
	return thing:EatAble();
end

function MultiOperationHelper:CanBeEquipt(thing)  --可以被小人装备
	local g_emItemLable = CS.XiaWorld.g_emItemLable;
	return (thing.def.Item ~= nil and thing.def.Item.Lable ~= g_emItemLable.Esoterica and thing.def.Item.Lable ~= g_emItemLable.FightFabao and 
			thing.def.Item.Lable ~= g_emItemLable.TreasureFabao and (not thing.IsMiBao));
end

function MultiOperationHelper:CanBePaint(thing)  --可以被画符
	local g_emItemLable = CS.XiaWorld.g_emItemLable;
	return thing.def.Item ~= nil and thing.def.Item.Lable == g_emItemLable.SpellPaper;
end

function MultiOperationHelper:CanBePut(thing)  --可以被放置
	local g_emItemLable = CS.XiaWorld.g_emItemLable;
	return (thing.def.Item ~= nil and thing.def.Item.Lable ~= g_emItemLable.Esoterica or thing.def.Item.Lable ~= g_emItemLable.FightFabao and
			thing.def.Item.Lable ~= g_emItemLable.TreasureFabao and (not thing.IsMiBao));
end

function MultiOperationHelper:CanMultiRefining(npc)  --ThingUICommandDefine
	return ((not npc.IsRent) and npc.EnemyType ~= CS.XiaWorld.Fight.g_emEnemyType.PlayerAttacker and 
			npc.GongKind == CS.XiaWorld.g_emGongKind.Dao and npc:CanDoMagic() and (not npc.IsVistor) and npc.CanDoDiscipleWork and
			(not npc.PropertyMgr:IsJobBan(CS.XiaWorld.g_emBehaviourWorkKind.Handwork)) and 
			npc.IsPlayerThing and npc.Rank == CS.XiaWorld.g_emNpcRank.Disciple );
end

function MultiOperationHelper:CanMultiMagic(npc)  --Panel_ThingInfo.UpdateBnts()
	if (npc.IsPlayerThing and npc.IsMagicRank and (not npc.IsVistor) and (not npc.IsGod) and npc.PropertyMgr.Practice.Magics.Count > 0 and (not npc.IsRent) and
		(not npc.FightBody.IsFighting) and (not npc:HasSpecialFlag(CS.XiaWorld.g_emNpcSpecailFlag.FLAG_THUNDERING)) and npc:CanDoMagic() and
		npc.EnemyType ~= CS.XiaWorld.Fight.g_emEnemyType.PlayerAttacker and (not npc:HasSpecialFlag(CS.XiaWorld.g_emNpcSpecailFlag.In_ZhenId))) then
		for _, magic in pairs(self.magic_name_list) do
			if npc.PropertyMgr.Practice.Magics:Contains(magic) then
				return true;
			end
		end			
	end
	return false;
end

function MultiOperationHelper:CanPaintCharm(npc)
	return ((not npc.IsRent) and npc.EnemyType ~= CS.XiaWorld.Fight.g_emEnemyType.PlayerAttacker and npc.GongKind == CS.XiaWorld.g_emGongKind.Dao and
			npc.IsPlayerThing and npc:CanDoMagic() and (not npc.IsVistor) and npc:CheckSpecialFlag(CS.XiaWorld.g_emNpcSpecailFlag.LostHand) < 2 and
			npc.CanDoDiscipleWork and npc.Rank == CS.XiaWorld.g_emNpcRank.Disciple);
end

function MultiOperationHelper:DoMultiOperation(thing, data)  --执行相应操作
	if self[data] ~= nil then
		self[data](self, thing);
		if (data == "MultiPutItem" or data == "MultiFuPainter") and CS.Wnd_RemoteStorage.Instance ~= nil and CS.Wnd_RemoteStorage.Instance.isShowing then
			CS.Wnd_RemoteStorage.Instance:Hide();
		end
	else
		self:MagicEnter(thing, data)
	end
end

function MultiOperationHelper:RemoveBtn(thing)  --移除添加的按键
	thing:RemoveBtnData("批量操作");
end

function MultiOperationHelper:MultiFuPainter(paper)  --选择画符的npc
	CS.Wnd_SelectNpc.Instance:Select(
		WorldLua:GetSelectNpcCallback(function(rs)
			if (rs == nil or rs.Count == 0) then
				return;
			end
			local npc = CS.XiaWorld.ThingMgr.Instance:FindThingByID(rs[0]);
			if npc ~= nil then
				if not self:CanPaintCharm(npc) then
					world:ShowMsgBox(string.format("[color=#0000FF]%s[/color]无法画符。", npc:GetName()));
					return;
				end
				self.MultiFuPainterWindow:Open(npc, paper, function(nc, pr, sp) self:Select2Paint(nc, pr, sp); end);
			end
		end), 
	CS.XiaWorld.g_emNpcRank.Disciple, 1, 1, nil, nil, "指定画符的角色");
end

function MultiOperationHelper:Select2Paint(npc, paper, spell_name_list)
	if #spell_name_list == 0 then
		return;
	end
	local count = self:CheckItemCount(paper, #spell_name_list, nil);
	if count > 0 then  --提示符纸数量不足
		local content = string.format(self.itemOperationTips.multiFuPainter, paper.Rate, paper:GetName(), count);
		self.OperationMsgWindow:ShowMsg(nil, content, "是", "否", function()
			self:AddPaintCharmCommand(npc, paper, spell_name_list);
		end);
	else
		self:AddPaintCharmCommand(npc, paper, spell_name_list);
	end	
end

function MultiOperationHelper:AddPaintCharmCommand(npc, paper, spell_name_list)
	--获取添加任务所需的符咒name
	local paper_list = self:GetActableItems(paper, #spell_name_list, nil);
	local command_def = CS.XiaWorld.CommandMgr.Instance:GetDef("PaintCharm");
	command_def.Single = 0;
	for i=1, math.min(#spell_name_list, #paper_list) do  --UILogicMode_IndividualCommand.Apply2Thing() case g_emIndividualCommandType.PaintCharm
		local fu_value = CS.XiaWorld.GlobleDataMgr.Instance:GetFuValue(spell_name_list[i]) * 0.95;  --符咒品质
		if fu_value == nil or fu_value <= 0 then
			fu_value = 1;
		end
		--print(paper_list[i].def.Name.."  "..spell_name_list[i]);
		local item = CS.XiaWorld.PracticeMgr.Instance:RandomSpellItem(paper_list[i].def.Name, spell_name_list[i], fu_value, -1, -1, false, paper_list[i].Rate);--生成符咒Item
		npc.Bag:AddItem(item, nil);
		item.Author = npc:GetName();
		local command = npc:AddCommand("PaintCharm", paper_list[i], CS.XLua.Cast.Int32(item.ID));
		--print(command.def.Single);
		local dict = {};
		dict["Name"] = spell_name_list[i];
		dict["Value"] = item:GetQuality();
		CS.GameWatch.Instance:BuryingPoint(CS.XiaWorld.BuryingPointType.Fu, dict);
	end
	self:InterruptGetFun(npc);
end

function MultiOperationHelper:MultiEatItem(item)  --选择食用的npc
	CS.Wnd_SelectNpc.Instance:Select(
		WorldLua:GetSelectNpcCallback(function(rs)
			if (rs == nil or rs.Count == 0) then
				return;
			end
			local input_item = {{
				name = "食用次数：", 
				id = "count", 
				data = "1", 
				desc = "每个人重复食用物品的次数。"
			}};
			self.NumberSettingWindow:Open("多人食用", nil, nil, nil, input_item, function(inputdata)
				if inputdata[1].data == 0 then
					return;
				end
				local npc_ids = {};
				local num = inputdata[1].data;
				for _, id in pairs(rs) do
					for i=1, num do
						table.insert(npc_ids, id);
					end
				end
				self:Select2Eat(npc_ids, item);
			end);
		end), 
	CS.XiaWorld.g_emNpcRank.Normal, 1, 99, nil, nil, "指定食用的角色");	
end

function MultiOperationHelper:Select2Eat(IDs, item)
	if IDs == nil or #IDs == 0 then
		return
	end
	local count = self:CheckItemCount(item, #IDs, nil);
	if count > 0 then  --提示物品数量不足
		local content = string.format(self.itemOperationTips.multiEatItem, item.Rate, item:GetName(), count);
		self.OperationMsgWindow:ShowMsg(nil, content, "是", "否", function()
			self:AddCommand2Eat(IDs, item);
		end);
	else
		self:AddCommand2Eat(IDs, item);
	end
end

function MultiOperationHelper:AddCommand2Eat(IDs, thing)  --逐个添加食用命令
	local item_list = self:GetActableItems(thing, #IDs, nil);
	for i=1, math.min(#IDs, #item_list) do
		local npc = CS.XiaWorld.ThingMgr.Instance:FindThingByID(IDs[i]);
		if npc ~= nil then			
			npc:AddCommand("EatItem", item_list[i]);
			self:InterruptGetFun(npc);
		end
	end
end

function MultiOperationHelper:MultiEquiptItem(item)  
	CS.Wnd_SelectNpc.Instance:Select(
		WorldLua:GetSelectNpcCallback(function(npcs)
			self:Select2Equipt(npcs, item);
		end), 
	CS.XiaWorld.g_emNpcRank.Normal, 1, 99, nil, nil, "指定装备的角色");	
end

function MultiOperationHelper:Select2Equipt(IDs, item)
	if IDs == nil or IDs.Count == 0 then
		return;
	end
	local npc_list = {};
	local names = {};
	for _, id in pairs(IDs) do
		local npc = CS.XiaWorld.ThingMgr.Instance:FindThingByID(id);
		if npc ~= nil then
			if npc:CheckEquipCell(item) == CS.XiaWorld.g_emEquipType.None then
				table.insert(names, npc:GetName());
			else
				table.insert(npc_list, id);
			end
		end
	end
	if #names > 0 then
		world:ShowMsgBox(string.format("[color=#0000FF]%s[/color]没有对应的装备槽了。", table.concat(names, "、")));
	end
	local count = self:CheckItemCount(item, #npc_list, function(it) return self:CheckItem2Equipt(it, item); end);
	if count > 0 then  --提示物品数量不足
		local content = string.format(self.itemOperationTips.multiEquiptItem, item.Rate, item:GetName(), count);
		self.OperationMsgWindow:ShowMsg(nil, content, "是", "否", function()
			self:AddCommand2Equipt(npc_list, item);
		end);
	else
		self:AddCommand2Equipt(npc_list, item);
	end
end

function MultiOperationHelper:AddCommand2Equipt(IDs, thing)  --逐个添加装备命令
	local item_list = self:GetActableItems(thing, #IDs, function(it) return self:CheckItem2Equipt(it, thing); end);
	for i=1, math.min(#IDs, #item_list) do
		local npc = CS.XiaWorld.ThingMgr.Instance:FindThingByID(IDs[i]);
		if npc ~= nil then
			npc:AddCommand("EquipItem", item_list[i]);
			self:InterruptGetFun(npc);
		end
	end
end

function MultiOperationHelper:CheckItem2Equipt(it, item)
	if item.def ~= nil and item.def.Item ~= nil and item.def.Item.Lable == CS.XiaWorld.g_emItemLable.Spell then
		return (it:GetName() == item:GetName());
	end
	if it.StuffDef ~= nil then
		return (it.StuffDef.Name == item.StuffDef.Name);
	end
	return (item.Bind2Npc == 0);
end

function MultiOperationHelper:MultiPutItem(item) 
	local tips = "按住左Shift键，鼠标左键点选置物台。";
	self.MultiSelectWindow:Open("批量放置", nil, nil, tips, function(shelf_list)
		self:Select2PutItem(shelf_list, item);
	end,
	nil, nil, CS.XiaWorld.g_emThingType.Building, function(tg)
		return (tg.BuildingState == CS.XiaWorld.g_emBuildingState.Working and tg.TagData:CheckTagString("ItemShelf"));
	end);
end

function MultiOperationHelper:Select2PutItem(shelf_list, item)
	if shelf_list == nil or #shelf_list == 0 then
		return;
	end
	local count = self:CheckItemCount(item, #shelf_list, nil);
	if count > 0 then
		local content = string.format(self.itemOperationTips.multiPutItem, item.Rate, item:GetName(), count);
		self.OperationMsgWindow:ShowMsg(nil, content, "是", "否", function()
			self:AddPutCommand(shelf_list, item);
		end);
	else
		self:AddPutCommand(shelf_list, item);
	end
end

function MultiOperationHelper:AddPutCommand(shelf_list, item) 
	local item_list = self:GetActableItems(item, #shelf_list, nil);
	for i=1, math.min(#shelf_list, #item_list) do
		local it = CS.XiaWorld.ThingMgr.Instance:FindThingByID(shelf_list[i].id);
		if it ~= nil then
			it.Bag:AddBegItem(item_list[i], 1, "PutCarry");
		end
	end
end

function MultiOperationHelper:CheckItemCount(item, count, condition)  --检查物品可操作的数量
	local item_name = item.def.Name;
	local item_count = CS.XiaWorld.World.Instance.Warehouse:GetItemCount(item_name);
	local item_all = CS.XiaWorld.World.Instance.map.Things:FindItems(nil, 0, item_count, item_name, 0, nil, 0, 9999, nil, false, false);
	if item_all ~= nil and item_all.Count > 0 then
		for _, it in pairs(item_all) do
			if it.Rate == item.Rate and (condition == nil or condition(it)) and (it.TagData:CheckTagString("_Remote") or 
				(it.LingPower <= 0 and it.FSItemState <= 0 and it.HelianValue == nil and base(it).CanStack)) then
				count = count - it.FreeCount;
				if count <= 0 then
					return 0;
				end
			end
		end
	end
	return count;
end

function MultiOperationHelper:GetActableItems(item, count, condition)  --获取可操作的物品
	local map = CS.XiaWorld.World.Instance.map;
	local item_list = {};
	local item_name = item.def.Name;
	local item_count = CS.XiaWorld.World.Instance.Warehouse:GetItemCount(item_name);
	local item_all = map.Things:FindItems(nil, 0, item_count, item_name, 0, nil, 0, 9999, nil, false, false);
	if item_all ~= nil and item_all.Count > 0 then  --先使用乾坤界外的物品
		for _, it in pairs(item_all) do
			if (not it.TagData:CheckTagString("_Remote")) and it.Rate == item.Rate and (condition == nil or condition(it)) and 
				it.LingPower <= 0 and it.FSItemState <= 0 and it.HelianValue == nil and base(it).CanStack then  --ItemThing.CanStack
				for i=1, it.FreeCount do
					table.insert(item_list, it);
					count = count - 1;
					if count <= 0 then
						return item_list;
					end
				end
			end
		end	
		for _, it in pairs(item_all) do  --不足则从乾坤界取，乾坤界物品是禁用状态
			if it.TagData:CheckTagString("_Remote") and it.Rate == item.Rate and (condition == nil or condition(it)) then
				local num_take = math.min(count, it.FreeCount);
				local item_take = map.SpaceRing:TakeOut(item_name, num_take, 0);
				for _, it_tk in pairs(item_take) do
					for i=1, it_tk.FreeCount do
						table.insert(item_list, it_tk);
					end
				end
				break;
			end
		end
	end	
	return item_list;
end

function MultiOperationHelper:MultiRefiningFabao(npc)  --设置批量炼宝
	local g_emItemLable = CS.XiaWorld.g_emItemLable;
	local tips = "按住左Shift键，鼠标左键点选物品；若物品的堆叠数>1，则可以设置个数。";
	self.MultiSelectWindow:Open("批量炼宝", nil, nil, tips, function(inputdata)
		self.refining_fabao_table = self.refining_fabao_table or {};
		self.refining_fabao_table[npc.ID] = nil;
		local items = {};
		for _, input in pairs(inputdata) do
			local cnt = 0;
			local it = CS.XiaWorld.ThingMgr.Instance:FindThingByID(input.id);
			if it ~= nil and it.FreeCount > 0 and input.data > 0 then
				cnt = math.min(it.FreeCount, input.data);
				for i=1, cnt do
					table.insert(items, input.id);
				end
			end
		end
		if #items > 0 then
			self.refining_fabao_table[npc.ID] = items;
		end
	end,
	nil, nil, CS.XiaWorld.g_emThingType.Item, function(tg)
		return (tg.def.Item ~= nil and tg.def.Item.Lable ~= g_emItemLable.FightFabao and tg.def.Item.Lable ~= g_emItemLable.TreasureFabao and 
				tg.def.Item.Lable ~= g_emItemLable.Esoterica and tg.Lock.FreeCount > 0);  --UILogicMode_IndividualCommand.CheckThing()
	end);
end

function MultiOperationHelper:CancelRefiningFabao(npc)  --取消批量炼宝
	if self.refining_fabao_table ~= nil and self.refining_fabao_table[npc.ID] ~= nil then
		self.refining_fabao_table[npc.ID] = nil;
	end
end

function MultiOperationHelper:AddRefiningFabao()  --检查并添加炼宝的命令
	local ThingMgr = CS.XiaWorld.ThingMgr.Instance;
	if self.refining_fabao_table ~= nil then
		for id, _ in pairs(self.refining_fabao_table) do
			local npc = ThingMgr:FindThingByID(id);
			if npc == nil or (not npc.IsDisciple) or npc.IsDeath or (not npc.IsPlayerThing) then
				self.refining_fabao_table[id] = nil;
			elseif npc:CheckCommandSingle("RefiningFabao", false) == nil and self.refining_fabao_table[id] ~= nil and #self.refining_fabao_table[id] > 0 and 
				(npc.JobEngine.CurJob ~= nil and npc.JobEngine.CurJob.jobdef ~= nil and npc.JobEngine.CurJob.jobdef.Name ~= "JobLeave2Explore") then
				local item = ThingMgr:FindThingByID(self.refining_fabao_table[id][1]);
				if item == nil then
					table.remove(self.refining_fabao_table[id], 1);
				elseif npc.LingV >= item.Rate * item.Rate * 500 and item.IsValid and item.FreeCount > 0 and item.AtG and item.InWhoseBag <= 0 and item.InWhoseHand <= 0 then
					npc:AddCommand("RefiningFabao", CS.XiaWorld.g_emItemLable.FightFabao, item, CS.XLua.Cast.Int32(0));
					self:InterruptGetFun(npc);
					table.remove(self.refining_fabao_table[id], 1);
					--print(npc.ID, item.ID);
				end
			end
			if self.refining_fabao_table[id] ~= nil and #self.refining_fabao_table[id] < 1 then
				self.refining_fabao_table[id] = nil;
			end
		end
	end	
end

function MultiOperationHelper:InterruptGetFun(npc)  --打断当前的娱乐
	local job = npc.JobEngine.CurJob;
	if job ~= nil and job.jobdef ~= nil then
		local job_type = job.jobdef.Name;
		if job_type == "JobLookAtSky" or job_type == "JobPlayWithBuilding" then
			job:InterruptJob();
		end
	end
end

function MultiOperationHelper:MagicEnter(npc, magic)  --点击某神通后进入对应的设置面板
	local ThingMgr = CS.XiaWorld.ThingMgr.Instance;
	local g_emThingType = CS.XiaWorld.g_emThingType;
	if npc == nil then
		return;
	end
	if magic == "CancelMagicAll" then
		self:CancelMagicAll(npc);
		return;
	end
	local magic_def = CS.XiaWorld.PracticeMgr.Instance:GetMagicDef(magic);
	if magic_def == nil then
		return;
	end
	local tips = self.magic_tips[magic_def.Name];
	if magic_def.Name == "AbsorbGong_5" or magic_def.Name == "AbsorbGong_6" then
		CS.Wnd_SelectNpc.Instance:Select(
			WorldLua:GetSelectNpcCallback(function(rs)
				if (rs == nil or rs.Count == 0) then
					return;
				end
				self:Magic2Cast(magic_def, npc, rs, rs.Count);
			end), 
		CS.XiaWorld.g_emNpcRank.Worker, 1, 99, nil, nil, magic_def.DisplayName);
	elseif magic_def.Name == "Prophesy_MapStory" or magic_def.Name == "LingCrystalMake" or magic_def.Name == "LingStoneMake" then
		local input_item = {{
			name = "施展次数：", 
			id = "count", 
			data = "", 
			desc = "重复施展神通的次数。"
		}};
		self.NumberSettingWindow:Open(magic_def.DisplayName, nil, nil, tips, input_item, function(inputdata)
			self:Magic2Cast(magic_def, npc, nil, inputdata[1].data);
		end);
	else
		local thing_type = nil;
		if magic_def.Name == "MakeSoulCrystal" then
			thing_type = g_emThingType.None;
		elseif magic_def.Name == "SoulCrystalYouPowerUp" or magic_def.Name == "FengshuiItemOpen" or magic_def.Name == "AbsorbLing_Item" then
			thing_type = g_emThingType.Item;
		elseif magic_def.Name == "PlantGrowUp" or magic_def.Name == "PlantGrowUp_Gong1" or magic_def.Name == "PlantGrowUp_Gong9" then
			thing_type = g_emThingType.Plant;
		elseif magic_def.Name == "SeachSoul" or magic_def.Name == "AbsorbLing_Body" or magic_def.Name == "AbsorbGong_1" or 
			magic_def.Name == "AbsorbGong_1_Gong9" or magic_def.Name == "AbsorbGong_2" or magic_def.Name == "AbsorbGong_2_Gong7" or 
			magic_def.Name == "AbsorbGong_3" or magic_def.Name == "AbsorbGong_3_Gong11" or magic_def.Name == "AbsorbGong_7" then
			thing_type = g_emThingType.Npc;
		end
		if thing_type ~= nil then
			self.MultiSelectWindow:Open(magic_def.DisplayName, nil, nil, tips, function(inputdata)
				local IDs = {};
				local index = 0;
				for _, input in pairs(inputdata) do
					local it = ThingMgr:FindThingByID(input.id);
					if self:CheckThing(npc, magic_def.Name, magic_def.SelectType, it) then
						if magic_def.Name == "SoulCrystalYouPowerUp" then
							local cnt = math.min(it.FreeCount, input.data);
							if it.FreeCount == 1 and it.Count == 1 then
								cnt = math.min(12, input.data);
							end
							for i=1, cnt do
								IDs[index] = input.id;
								index = index + 1;							
							end
						else
							IDs[index] = input.id;
							index = index + 1;
						end
					end
				end
				self:Magic2Cast(magic_def, npc, IDs, index);
			end,
			nil, nil, thing_type, function(tg)
				return self:CheckThing(npc, magic_def.Name, magic_def.SelectType, tg);
			end);	
		end
	end
end

function MultiOperationHelper:CheckThing(npc, magic, stype, thing)  --检查thing是否可作为神通的对象  UILogicMode_IndividualCommand.CheckThing  case对应SelectType（Settings\Practice\Magic.xml）
	local g_emNpcSpecailFlag = CS.XiaWorld.g_emNpcSpecailFlag;
	local g_emPlantKind = CS.XiaWorld.g_emPlantKind;
	local CommandType = CS.XiaWorld.g_emIndividualCommandType;
	local g_emThingType = CS.XiaWorld.g_emThingType;
	if magic ~= nil and thing ~= nil and thing.Lock.FreeCount > 0 then
		if (magic == "SoulCrystalYouPowerUp") or 
			(magic == "AbsorbLing_Item" and thing.LingV > 0) or
			(magic == "FengshuiItemOpen" and thing.FSItemState == 1) then
			return true;
		end
		if magic == "SeachSoul" and thing.IsLingering and (not thing:HasSpecialFlag(g_emNpcSpecailFlag.FLAG_MAGIC)) and 
			(not thing:HasSpecialFlag(g_emNpcSpecailFlag.FLAG_SeachSoul)) then
			return true;
		end
		if stype == CommandType.Plant and (thing.def.Plant.Kind == g_emPlantKind.HighPlant or thing.def.Plant.Kind == g_emPlantKind.LowPlant) then
			return true;
		end
		if magic == "MakeSoulCrystal" and ((thing.ThingType == g_emThingType.Npc and thing.IsValid and (not thing.IsCorpse) and (not thing.IsPuppet) and 
			(not thing.IsZombie) and (not thing.IsDisciple or thing.IsLingering) and (not thing:HasSpecialFlag(g_emNpcSpecailFlag.FLAG_CANTBEMAGIC)) and 
			(not thing:HasSpecialFlag(g_emNpcSpecailFlag.FLAG_MAGIC)) and (not thing:HasSpecialFlag(g_emNpcSpecailFlag.FLAG_DROPSOULCRYSTAL))) or 
			((thing.ThingType == g_emThingType.Building or thing.ThingType == g_emThingType.Plant or thing.ThingType == g_emThingType.Item) and 
			CS.XiaWorld.TongLingMgr.Instance:IsJingGuai(thing.ID))) then
			return true;
		end
		if magic == "AbsorbLing_Body" and thing.IsCorpse and (not thing.IsBoss) and (not thing.IsPuppet) and (not thing.IsZombie) and 
			(not thing:HasSpecialFlag(g_emNpcSpecailFlag.FLAG_CANTBEMAGIC)) and (not thing:HasSpecialFlag(g_emNpcSpecailFlag.FLAG_MAGIC)) and
			(thing:CheckSpecialFlag(g_emNpcSpecailFlag.PuppetBindNpc) <= 0) then
			return true;
		end
		if (stype == CommandType.NormalNpc or stype == CommandType.NormalNpcRace or stype == CommandType.NormalRaceSexNpc) and
			thing.IsValid and (not thing.IsDeath) and (not thing.IsPuppet) and (not thing.IsZombie) and (not thing.IsDisciple) and
			((stype ~= CommandType.NormalNpcRace and stype ~= CommandType.NormalRaceSexNpc) or npc.Race == thing.Race) and 
			(stype ~= CommandType.NormalRaceSexNpc or npc.Sex ~= thing.Sex) and (not thing:HasSpecialFlag(g_emNpcSpecailFlag.FLAG_CANTBEMAGIC)) and 
			(not thing:HasSpecialFlag(g_emNpcSpecailFlag.FLAG_MAGIC)) then
			return true;
		end
	end
	return false;
end

function MultiOperationHelper:Magic2Cast(magic_def, npc, targets, count)  --设置后确定施展神通
	local re = self:CheckEnable(magic_def, npc, count);
	if re[2] < count then
		local content = string.format("只能施展神通%d次[color=#FF0000]（%s）[/color]。是否施展神通？", re[2], re[1]);
		self.OperationMsgWindow:ShowMsg(nil, content, "是", "否", function() 
			self:AddMagicCommand(magic_def, npc, targets, re[2]); 
		end);
	else
		self:AddMagicCommand(magic_def, npc, targets, count);
	end
end

function MultiOperationHelper:CheckEnable(magic_def, npc, count)  --NpcMagicBnt.CheckEnable()  检查施展神通条件是否满足
	local World = CS.XiaWorld.World.Instance;
	local ThingMgr = CS.XiaWorld.ThingMgr.Instance;
	local g_emThingType = CS.XiaWorld.g_emThingType;
	local Map = CS.XiaWorld.World.Instance.map;
	local text = {};
	local valid_count = count;
	if npc.LingV < magic_def.CostLing * count then
		valid_count = math.min(valid_count, math.floor(npc.LingV / magic_def.CostLing));
		table.insert(text, "灵气不足");
	end
	if npc.MaxAge - npc.Age < magic_def.CostAge * count then
		valid_count = math.min(valid_count, math.floor((npc.MaxAge - npc.Age) / magic_def.CostAge));
		table.insert(text, "寿元不足");
	end
	if npc.PropertyMgr.Practice.StageValue < magic_def.CostGong * count then
		valid_count = math.min(valid_count, math.floor(npc.PropertyMgr.Practice.StageValue / magic_def.CostGong));
		table.insert(text, "修为不足");			
	end
	if magic_def.ItemCost ~= nil and magic_def.ItemCost.Count > 0 and magic_def.Name ~= "SoulCrystalYouPowerUp" then
		for _, data in pairs(magic_def.ItemCost) do
			if World.Warehouse:GetItemCount(data.name) < data.count * count then
				valid_count = math.min(valid_count, math.floor(World.Warehouse:GetItemCount(data.name) / data.count));
				table.insert(text, string.format("%s不足", ThingMgr:GetDef(g_emThingType.Item, data.name).ThingName));
			end
		end
	end
	if magic_def.Name == "SoulCrystalYouPowerUp" then  --UILogicMode_IndividualCommand.Apply2Thing() case g_emIndividualCommandType.SoulCrystalYouPowerUp
		local item_count = World.Warehouse:GetItemCount("Item_SoulCrystalYou");
		local item_all = Map.Things:FindItems(nil, 0, item_count, "Item_SoulCrystalYou", 0, nil, 0, 9999, nil, false, false);
		local ct = 0;
		if item_all ~= nil and item_all.Count > 0 then
			for _, it in pairs(item_all) do
				if it.TagData:CheckTagString("_Remote") or it.Actable then  --乾坤界中的物品是禁用状态的
					ct = ct + it.FreeCount;
					if ct >= count then
						break;
					end
				end
			end
		end
		if ct < count then
			valid_count = math.min(valid_count, ct);
			table.insert(text, string.format("%s不足", ThingMgr:GetDef(g_emThingType.Item, "Item_SoulCrystalYou").ThingName));
		end
	end
	text = table.concat(text, "、");
	return {text, valid_count}
end

function MultiOperationHelper:AddMagicCommand(magic_def, npc, targets, count)  --添加施展神通命令
	local ThingMgr = CS.XiaWorld.ThingMgr.Instance;
	local Map = CS.XiaWorld.World.Instance.map;
	local g_emIndividualCommandType = CS.XiaWorld.g_emIndividualCommandType;
	local g_emThingType = CS.XiaWorld.g_emThingType;
	if magic_def.CMD ~= nil then
		local command_def = CS.XiaWorld.CommandMgr.Instance:GetDef(magic_def.CMD);
		command_def.Single = 0;
		--print(magic_def.CMD)
	end
	for i=0, count-1 do  --NpcMagicBnt.GetBntData()
		if magic_def.Type == CS.XiaWorld.MagicDef.MagicType.Class then
			if magic_def.SelectMode ~= CS.XiaWorld.g_emSelectMode.None then  --UILogicMode_MagicCommand
				local thing = ThingMgr:FindThingByID(targets[i]);
				local command = npc:AddCommand("MagicNormal", nil, true, magic_def.Name);
				if command ~= nil then
					self:ThingSetIcon(thing);
					command.keys = {targets[i]};
					command.WorkParam3 = magic_def.Name;
					command.EventOnFinished = function(del) 
						self:ThingRemoveIcon(thing);
					end
				end
			else
				local command = npc:AddCommand("MagicNormal", nil, false, magic_def.Name);
				if command ~= nil then
					command.WorkParam3 = magic_def.Name;
				end
			end
		elseif magic_def.SelectType ~= g_emIndividualCommandType.None then
			local thing = ThingMgr:FindThingByID(targets[i]);
			if magic_def.SelectType == g_emIndividualCommandType.SoulCrystalYouPowerUp then  --UILogicMode_IndividualCommand.Apply2Thing() case g_emIndividualCommandType.SoulCrystalYouPowerUp
				local cost_item = Map.Things:FindItem(nil, 9999, "Item_SoulCrystalYou", 0, false, nil, 0, 9999, nil, false);
				if cost_item == nil then
					world:ShowMsgBox("物品[color=#0000FF]幽珀[/color]数量不足。请确认物品是否被禁用。");
					break;
				end
				local command = npc:AddCommand(magic_def.CMD, thing); 
				if command ~= nil then
					self:ThingSetIcon(thing);
					cost_item.Lock:Lock(command, 1);
					command.WorkParam2 = CS.XLua.Cast.Int32(cost_item.ID); 
					command.WorkParam3 = magic_def.Name;
					command.EventOnFinished = function(del) 
						self:ThingRemoveIcon(thing);
					end
					if thing.Lock.FreeCount < 1 then
						thing.Lock:UnLockAllByOwner(command);
					end
				end
			elseif magic_def.SelectType == g_emIndividualCommandType.NormalNpcRace and (magic_def.Name == "AbsorbGong_5" or magic_def.Name == "AbsorbGong_6") then 
				if thing:HasSpecialFlag(CS.XiaWorld.g_emNpcSpecailFlag.FLAG_MAGIC) then
					world:ShowMsgBox(string.format("[color=#0000FF]%s[/color]已经是神通的施展对象，暂时无法成为神通对象。请取消神通或稍候再试。", thing:GetName()));
				else
					local command = npc:AddCommand(magic_def.CMD, thing);
					if command ~= nil then
						command.WorkParam3 = magic_def.Name;
					end
				end
			elseif magic_def.SelectType == g_emIndividualCommandType.MakeSoulCrystal then
				local command = nil;
				if thing.ThingType == g_emThingType.Npc then
					command = npc:AddCommand(magic_def.CMD, thing);
				else
					command = npc:AddCommand(magic_def.CMD, nil, nil, thing);
				end
				if command ~= nil then
					self:ThingSetIcon(thing);
					command.WorkParam3 = magic_def.Name;
					command.EventOnFinished = function(del) 
						self:ThingRemoveIcon(thing);
					end	
				end
			elseif magic_def.SelectType == g_emIndividualCommandType.DieStay or magic_def.SelectType == g_emIndividualCommandType.Plant or 
				magic_def.SelectType == g_emIndividualCommandType.AbsorbLing_Item or magic_def.SelectType == g_emIndividualCommandType.AbsorbLing_Body or 
				magic_def.SelectType == g_emIndividualCommandType.NormalNpc or magic_def.SelectType == g_emIndividualCommandType.NormalNpcRace or 
				magic_def.SelectType == g_emIndividualCommandType.NormalRaceSexNpc then
				local command = npc:AddCommand(magic_def.CMD, thing);
				if command ~= nil then
					self:ThingSetIcon(thing);
					command.WorkParam3 = magic_def.Name;
					command.EventOnFinished = function(del) 
						self:ThingRemoveIcon(thing);
					end	
				end
			end
		else
			local command = npc:AddCommand(magic_def.CMD, npc);
			if command ~= nil then
				command.WorkParam3 = magic_def.Name;
			end
		end
	end
	self:InterruptGetFun(npc);
end

function MultiOperationHelper:CheckMagicCommand(npc)  --获取npc所有待执行的神通命令
	local cmd_all = {};
	for _, magic in pairs(self.magic_name_list) do
		local magic_def = CS.XiaWorld.PracticeMgr.Instance:GetMagicDef(magic);
		if magic_def ~= nil then
			local magic_type = magic_def.CMD;
			if magic_def.Type == CS.XiaWorld.MagicDef.MagicType.Class then
				magic_type = "MagicNormal";
			end
			local cmd_list = npc:CheckCommand(magic_type, false);
			if cmd_list ~= nil and cmd_list.Count > 0 then
				for _, cmd in pairs(cmd_list) do
					if cmd.WorkParam3 == magic_def.Name then
						table.insert(cmd_all, cmd);
					end
				end
			end
		end
	end
	return cmd_all;
end

function MultiOperationHelper:CancelMagicAll(npc)  --取消npc所有待执行的神通命令
	local cmd_list = self:CheckMagicCommand(npc);
	for _, cmd in pairs(cmd_list) do
		--print(cmd.ID);
		cmd:FinishCommand(true, false);
	end
end

function MultiOperationHelper:SelectAllNpc()  --npc全选
	local Wnd_SelectNpc = CS.Wnd_SelectNpc.Instance;
	if Wnd_SelectNpc ~= nil and Wnd_SelectNpc.isShowing then
		xlua.private_accessible(CS.Wnd_SelectNpc);
		if Wnd_SelectNpc.MaxCount > 1 then
			if Wnd_SelectNpc.UIInfo.m_n25:GetSelection().Count == Wnd_SelectNpc.UIInfo.m_n25.numItems then  --已全选，则全取消
				Wnd_SelectNpc.UIInfo.m_n25:ClearSelection();
			else
				local num = math.min(Wnd_SelectNpc.UIInfo.m_n25.numItems, Wnd_SelectNpc.MaxCount);
				for i=0, num-1 do
					local list_item = Wnd_SelectNpc.UIInfo.m_n25:GetChildAt(i);
					if not list_item.grayed then
						Wnd_SelectNpc.UIInfo.m_n25:AddSelection(i, false);
					end
				end				
			end
			Wnd_SelectNpc:OnListClick(nil);
		end
	end
end

function MultiOperationHelper:ThingSetIcon(thing)  --在thing上添加icon标记
	if thing ~= nil then
		local th_view;
		if thing.View ~= nil then
			th_view = thing.View;
		elseif thing.view ~= nil then
			th_view = thing.view;
		end
		if th_view ~= nil then
			th_view:SetIcon("res/Sprs/ui/icon_lingxi01");  --标记
		end		
	end
end

function MultiOperationHelper:ThingRemoveIcon(thing)  --移除thing上的icon标记
	if thing ~= nil then
		local th_view = nil;
		if thing.View ~= nil then
			th_view = thing.View;
		elseif thing.view ~= nil then
			th_view = thing.view;
		end
		if th_view ~= nil then
			if thing.ThingType == CS.XiaWorld.g_emThingType.Item and not thing.Actable then  --Item上是否有禁用的标记
				th_view:SetIcon("res/Sprs/ui/icon_ban");
			else
				th_view:RemoveIcon();
			end
		end
	end
end

--[[
function MultiOperationHelper:ConfigChanged()
	if not self.config.multiRefiningFabao then
		self.refining_fabao_table = {};
	end
end
]]--

function MultiOperationHelper:CheckModLegal()
	local mod_name = "MultiOperationHelper";
	local mod_display_name = "批量操作Helper";
	for _, mod in pairs(CS.ModsMgr.Instance.AllMods) do
		if (mod.IsActive and mod.Name == mod_name and mod.Author == "枫轩" and (mod.ID == "1866576765" or mod.ID == "2199817102947266095" or mod.ID == "2199817102947260321")) then
			return true;
		end
	end
	print(string.format("The mod: '%s' is illegal", mod_display_name));
	return false
end

function MultiOperationHelper:OnSetHotKey()
	local tbHotKey = {
		{ID = "SelectAllNpc" , Name = "全选(批量操作)" , Type = "Mod", InitialKey1 = "LeftControl+A" },
--		{ID = "MultiOperationConfig" , Name = "批量操作设置" , Type = "Mod", InitialKey1 = "RightControl+K" }				
	};
	return tbHotKey;
end

function MultiOperationHelper:OnHotKey(ID, state)
	if not self.mod_enable then
		return;
	end
	if ID == "SelectAllNpc" and state == "down" then
		self:SelectAllNpc();
	end
end

function MultiOperationHelper:OnStep(dt)
	if not self.mod_enable then
		return;
	end
	self:AddRefiningFabao();
end

function MultiOperationHelper:OnLeave()
	print("MultiOperationHelper Leave");
end

function MultiOperationHelper:OnSave()--系统会将返回的table存档 table应该是纯粹的KV
	local save_data = {
		refining_fabao = self.refining_fabao_table,
	}
	return save_data;
end

function MultiOperationHelper:OnLoad(tbLoad)--读档时会将存档的table回调到这里
	SaveData = tbLoad or {};
end

MultiOperationHelper.magic_name_list = {
	"SeachSoul",				--搜魂
	"SoulCrystalYouPowerUp",	--幽淬
	"AbsorbGong_5",				--他化
	"AbsorbGong_6",				--寄生
	"LingCrystalMake",			--炼制灵晶
	"LingStoneMake",			--炼制灵石
	"Prophesy_MapStory",		--大衍神算
	"FengshuiItemOpen",			--风水鉴定
	"PlantGrowUp",				--御木诀
	"PlantGrowUp_Gong1",		--天霖诀
	"PlantGrowUp_Gong9",		--万木回春
	"AbsorbLing_Item",			--吸星掌
	"MakeSoulCrystal",			--凝珀诀
	"AbsorbLing_Body",			--天妖化血术
	"AbsorbGong_1",				--鼎炉吸真术
	"AbsorbGong_1_Gong9",		--元央归息法
	"AbsorbGong_2",				--风月幻境
	"AbsorbGong_2_Gong7",		--如意幻境
	"AbsorbGong_3",				--摄神御鬼大法
	"AbsorbGong_3_Gong11",		--九幽炼神
	"AbsorbGong_7",				--献祭
};

MultiOperationHelper.magic_tips = {
	["SeachSoul"] = "按住左Shift键，鼠标左键点选小人，已搜魂或被其他操作锁定的小人无法被选中。",
	["SoulCrystalYouPowerUp"] = "按住左Shift键，鼠标左键点选物品。若物品的堆叠数=1，则可以设置幽淬的次数；若物品的堆叠数>1，则可以设置幽淬的个数。幽淬次数范围0--12，幽淬个数范围0--99。",
	["FengshuiItemOpen"] = "按住左Shift键，鼠标左键点选物品，被其他操作锁定的物品无法被选中。",
	["AbsorbLing_Item"] = "按住左Shift键，鼠标左键点选物品，被其他操作锁定的物品无法被选中。",
	["PlantGrowUp"] = "按住左Shift键，鼠标左键点选植物，被其他操作锁定的植物无法被选中。",
	["PlantGrowUp_Gong1"] = "按住左Shift键，鼠标左键点选植物，被其他操作锁定的植物无法被选中。",
	["PlantGrowUp_Gong9"] = "按住左Shift键，鼠标左键点选植物，被其他操作锁定的植物无法被选中。",
	["MakeSoulCrystal"] = "按住左Shift键，鼠标左键点选小人或精怪，被其他操作锁定的目标无法被选中。",
};

MultiOperationHelper.operationDef = {
	itemOperation = {dspName = "批量操作", icon = "res/Sprs/ui/icon_sousuo01", data = "ShowItemMenu", tooltips = "打开批量操作菜单"};
	npcOperation = {dspName = "批量操作", icon = "res/Sprs/ui/icon_sousuo01", data = "ShowNpcMenu", tooltips = "打开批量操作菜单"};
	multiEatItem = {bg = 0, grayed = false, dspName = "多人食用", icon = "res/Sprs/ui/icon_shiyong01", data = "MultiEatItem", tooltips = "选择单个或多个小人，食用同品阶同名称的物品，并可设置连续食用多次（包括体修的吞噬等）。"};
	multiEquiptItem = {bg = 0, grayed = false, dspName = "多人装备", icon = "res/Sprs/ui/icon_zhuangbeidaoju01", data = "MultiEquiptItem", tooltips = "选择单个或多个小人，装备同品阶同材料的物品。"};
	multiFuPainter = {bg = 0, grayed = false, dspName = "批量画符", icon = "res/Sprs/ui/icon_huafu01", data = "MultiFuPainter", tooltips = "使用同品阶同类型的符纸，进行批量画符，可设置画多种不同的符咒。"};
	multiPutItem = {bg = 0, grayed = false, dspName = "批量放置", icon = "res/Sprs/ui/icon_fangzhiwupin01", data = "MultiPutItem", tooltips = "选择单个或多个置物台，放置同品阶同名称的物品。"};
	multiRefiningFabao = {bg = 0, grayed = false, dspName = "批量炼宝", icon = "res/Sprs/ui/icon_lianbao01", data = "MultiRefiningFabao", tooltips = "选择单个或多个物品，自动进行炼宝。"};
	cancelRefiningFabao = {bg = 0, grayed = false, dspName = "取消批量炼宝", icon = "res/Sprs/ui/icon_lianbao01", data = "CancelRefiningFabao", tooltips = "取消所有剩余的炼宝任务，正在炼制的法宝不会被取消。"};
};

MultiOperationHelper.itemOperationTips = {
	multiEatItem = "缺少[color=#0000FF]%d品阶[/color]的[color=#0000FF]%s[/color]%d个，是否食用？\n[color=#FF0000]（请确认物品是否被禁用）[/color]",
	multiEquiptItem = "缺少[color=#0000FF]%d品阶[/color]的[color=#0000FF]%s[/color]%d个，是否装备？\n[color=#FF0000]（请确认物品是否被禁用）[/color]",
	multiFuPainter = "缺少[color=#0000FF]%d品阶[/color]的[color=#0000FF]%s[/color]%d张，是否画符？\n[color=#FF0000]（请确认符纸是否被禁用）[/color]",
	multiPutItem = "缺少[color=#0000FF]%d品阶[/color]的[color=#0000FF]%s[/color]%d个，是否放置？\n[color=#FF0000]（请确认物品是否被禁用）[/color]",
};

--[[
MultiOperationHelper.configItems = {
	{name = "multiEatItem", dspName = "多人食用", default = true, tooltips = "选中物品时，添加【多人食用】按键"},
	{name = "multiEquiptItem", dspName = "多人装备", default = true, tooltips = "选中物品时，添加【多人装备】按键"},
	{name = "multiFuPainter", dspName = "批量画符", default = true, tooltips = "选中符纸时，添加【批量画符】按键"},
	{name = "multiMagic", dspName = "批量神通", default = true, tooltips = "选中小人时，添加【批量神通】按键"},
	{name = "multiRefiningFabao", dspName = "批量炼宝", default = true, tooltips = "选中小人时，添加【批量炼宝】按键"},
};
]]--

--UILogicMode_IndividualCommand.Apply2Thing()
--ThingUICommandDefine
--CommandMgr, CommandTypeDef
--Thing.AddBtnData()
--Panel_ThingInfo.UpdateBnts()
--EventMgr, g_emEvent
--MagicDef
--NpcMagicBnt.GetBntData()
--GObject, GComponent
--Wnd_SelectThing.OnShowUpdate()
--Npc.JobEngine.CurJob.GetDesc()
--Wnd_SelectNpc
--UILogicMode_IndividualCommand.CheckThing()

--[[
CS.XiaWorld.PracticeMgr.Instance:GetSpellDef
CS.XiaWorld.GlobleDataMgr.Instance:GetFuValue
CS.XiaWorld.World.Instance.map.Things:GetNpcByKey
CS.XiaWorld.World.Instance.map.Things:GetThingAtGrid
CS.XiaWorld.GridMgr.Inst:KeyVaild
CS.XiaWorld.ThingMgr.Instance:FindThingByID
CS.XiaWorld.RemoteStorage
CS.XiaWorld.PracticeMgr.Instance:GetMagicDef
CS.XiaWorld.ThingMgr.Instance:GetDef
CS.XiaWorld.World.Instance.Warehouse:GetItemCount
CS.Wnd_SelectNpc.Instance:Select
CS.XiaWorld.CommandMgr.Instance:GetDef
CS.XiaWorld.PracticeMgr.Instance:RandomSpellItem
CS.GameWatch.Instance:BuryingPoint
CS.XiaWorld.World.Instance.map.Things:FindItems
CS.XiaWorld.World.Instance.map.Things:FindItem
Thing:HasSpecialFlag
CS.Wnd_SelectNpc.Instance:OnListClick
Thing:CheckCommandSingle
ItemThing:EatAble
Npc:CanDoMagic
Npc.PropertyMgr:IsJobBan
Thing:RemoveBtnData
Thing.Bag:AddItem
Thing:AddCommand
Thing:GetQuality
Thing:GetName
Npc:CheckEquipCell
Thing.Bag:AddBegItem
Thing.TagData:CheckTag
Thing.TagData:CheckTagString
ItemThing.Lock:Lock
ItemThing.Lock:UnLockAllByOwner
Command:FinishCommand
CS.ThingViewBase:SetIcon
CS.ThingViewBase:RemoveIcon
]]--

