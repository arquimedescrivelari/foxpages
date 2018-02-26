/*jslint nomen: true, sloppy: true*/

/*globals
$:true, define:true, dojo:true, dijit:true,
dataSection:true,
groupsRest:true, groupsModel:true, groupsTree:true,
clientsRest:true, clientsStore:true, clientsGrid:true, clientData:true, clientRest:true,
ordersRest:true, ordersStore:true, ordersGrid:true, orderRest:true,
billsRest:true, billsStore:true, billsGrid:true,
itensRest:true, itensMemory:true, itensCache:true, itensStore:true, itensGrid:true, itensEdit:true,
orderTotal:true,
productsRest:true, productsMemory:true,
receivingRest:true,
statesRest:true, transportersRest:true,
editGroupDialog:true, editGroupForm:true, editGroupCancel:true,
newGroupDialog:true, newGroupForm:true, newGroupCancel:true,
editGroupDialog:true, editGroupCancel:true,
editClientDialog:true, editClientForm:true, editClientCancel:true,
moveClientDialog:true, moveClientForm:true, moveClientCancel:true,
editOrderDialog:true, editOrderForm:true, editOrderAddItem:true, editOrderDeleteItem:true, editOrderSubmit:true, editOrderCancel:true,
mnuLogout:true, mnuNewGroup:true, mnuRenameGroup:true, mnuDeleteGroup:true,
mnuNewClient:true, mnuEditClient:true, mnuMoveClient:true, mnuDeleteClient:true,
mnuNewOrder:true, mnuEditOrder:true, mnuDeleteOrder:true,
ctxMnuRenameGroup:true, ctxMnuDeleteGroup:true,
ctxMnuEditClient:true, ctxMnuMoveClient:true, ctxMnuDeleteClient:true,
ctxMnuEditOrder:true, ctxMnuDeleteOrder:true,
okDialog:true, okDialogOK:true,
formatCurrency:true, formatDate:true, formatPercentage:true, formatProduct:true,
endLoading:true
*/


define([
	"dojo/dom",
	"dojo/dom-style",
	"dojo/on",
	"dojo/currency",
	"dojo/_base/fx",
	"dojo/_base/lang",
	"dojo/_base/xhr",
	"dojo/date/locale",
	"dojo/store/JsonRest",
	"dojo/store/Memory",
	"dojo/store/Cache",
	"dojo/data/ObjectStore",
	"dijit/tree/ObjectStoreModel",
	"dijit/registry",
	"dijit/Dialog",
	"dijit/form/Form",
	"dijit/form/Button",
	"dijit/form/CheckBox",
	"dijit/form/ComboBox",
	"dijit/form/CurrencyTextBox",
	"dijit/form/DateTextBox",
	"dijit/form/FilteringSelect",
	"dijit/form/NumberTextBox",
	"dijit/form/SimpleTextarea",
	"dijit/form/TextBox",
	"dijit/form/ValidationTextBox",
	"dojo/parser",
	"dijit/Menu",
	"dijit/MenuBar",
	"dijit/MenuItem",
	"dijit/MenuSeparator",
	"dijit/PopupMenuBarItem",
	"dijit/Tree",
	"dijit/layout/BorderContainer",
	"dijit/layout/TabContainer",
	"dijit/layout/ContentPane",
	"dojox/form/BusyButton",
	"dojox/grid/DataGrid",
	"dojox/grid/cells/dijit"],
	function (dom, domStyle, on, currency, baseFx, lang, xhr, locale, JsonRest, Memory, Cache, ObjectStore, ObjectStoreModel, registry, Dialog, Form, Button, CheckBox, ComboBox, CurrencyTextBox, DateTextBox, FilteringSelect, NumberTextBox, TextArea, TextBox, ValidationTextBox, parser) {
		var selectedDataClient, selectedOrderClient, selectedBillClient, loadClientsData, loadOrdersData, itensCounter, okDialogMsg;
		
		loadClientsData = true;
		loadOrdersData = true;
	
		// Rest store for groups data
		groupsRest = new JsonRest({
			target: "/representante/rest/groups",
			getChildren: function (object) {
				return object.children || [];
			},
			remove: function (id, options) {
				options = options || {};
				return xhr("DELETE", {
					url: this._getTarget(id),
					handleAs: "json",
					headers: lang.mixin({
						"Content-Type": "application/json",
						Accept: this.accepts
					}, this.headers, options.headers)
				});
			}
		});

		// Object store model for groups data
		groupsModel = new ObjectStoreModel({
			store: groupsRest,
			query: {},
			mayHaveChildren: function (item) {
				return item.hasOwnProperty("children");
			}
		});

		// Rest store for clients data
		clientsRest = new JsonRest({
			target: "/representante/rest/clients"
		});
		
		// Object store for clients data
		clientsStore = new ObjectStore({
			objectStore: clientsRest
		});

		// Rest store for selected client
		clientRest = new JsonRest({
			idProperty: "cf_codigo",
			target: "/representante/rest/client",
			remove: function (id, options) {
				options = options || {};
				return xhr("DELETE", {
					url: this._getTarget(id),
					handleAs: "json",
					headers: lang.mixin({
						"Content-Type": "application/json",
						Accept: this.accepts
					}, this.headers, options.headers)
				});
			}
		});
		
		// Rest store for orders data
		ordersRest = new JsonRest({
			target: "/representante/rest/orders"
		});
		
		// Object store for orders data
		ordersStore = new ObjectStore({
			objectStore: ordersRest
		});

		// Rest store for bills data
		billsRest = new JsonRest({
			target: "/representante/rest/bills"
		});
		
		// Object store for bills data
		billsStore = new ObjectStore({
			objectStore: billsRest
		});

		// Rest store for selected order
		orderRest = new JsonRest({
			idProperty: "pe_codigo",
			target: "/representante/rest/order",
			remove: function (id, options) {
				options = options || {};
				return xhr("DELETE", {
					url: this._getTarget(id),
					handleAs: "json",
					headers: lang.mixin({
						"Content-Type": "application/json",
						Accept: this.accepts
					}, this.headers, options.headers)
				});
			}
		});
	
		// Rest store for selected order itens
		itensRest = new JsonRest({
			target: "/representante/rest/itens",
			idProperty: "pi_codigo"
		});

		// Memory store for selected order itens
		itensMemory = new Memory({idProperty: "pi_codigo"});
	
		// Cache store for selected order itens
		itensCache = new Cache(itensRest, itensMemory);
	
		// Object store for selected order itens
		itensStore = new ObjectStore({objectStore: itensCache});

		orderTotal = function () {
			var i, item, desc, acres, total;
			
			desc = dijit.byId("edit_order_pe_desc").get("value");
			acres = dijit.byId("edit_order_pe_acres").get("value");
			
			total = 0;
			for (i = 0; i < itensGrid.rowCount; i = i + 1) {
				item = itensGrid.getItem(i);

				total = total + item.pi_valort;
			}
			
			dijit.byId("edit_order_pe_valor").set("value", total);
			dijit.byId("edit_order_pe_valort").set("value", total - (isNaN(desc) ? 0 : desc) + (isNaN(acres) ? 0 : acres));
		};

		// Itens edit
		itensEdit = function (inValue, inRowIndex, inFieldIndex) {
			var i, item, product, store;
			item = itensGrid.getItem(inRowIndex);
			store = itensGrid.store;
            product = productsMemory.get(item.pi_prod);
			
            switch (inFieldIndex) {
			case "pi_prod":
				if (product) {
					store.setValue(item, "pi_prod", product.pr_codigo);
					store.setValue(item, "pr_descr", product.pr_descr);
					store.setValue(item, "pi_preco", product.pc_preco);
					store.setValue(item, "pi_valor", product.pc_preco);
					store.setValue(item, "pi_desc", 0);
				} else {
					store.setValue(item, "pi_prod", "");
					store.setValue(item, "pr_descr", "");
					store.setValue(item, "pi_preco", 0);
					store.setValue(item, "pi_valor", 0);
					store.setValue(item, "pi_desc", 0);
				}
				break;
			case "pi_valor":
                if (isNaN(item.pi_valor)) {
                    if (product) {
                        item.pi_valor = product.pc_preco;
                        item.pi_desc = 0;
                    } else {
                        item.pi_valor = 0;
                        item.pi_desc = 0;
                    }
                } else if (item.pi_valor < item.pi_preco) {
                    if (item.pi_valor <= 0) {
                        if (product) {
                            item.pi_valor = product.pc_preco;
                            item.pi_desc = 0;
                        } else {
                            item.pi_valor = 0;
                            item.pi_desc = 0;
                        }
                    } else {
                        item.pi_desc = dojo.number.round(100 - (item.pi_valor * 100 / item.pi_preco), 2);
                    }
				} else if (item.pi_valor > item.pi_preco) {
					item.pi_preco = item.pi_valor;
					item.pi_desc  = 0;
				} else {
					item.pi_desc = 0;
				}
				break;
            case "pi_desc":
				if (isNaN(item.pi_desc)) {
					item.pi_desc = 0;
				}
					
				store.setValue(item, "pi_valor", item.pi_preco * ((100 - item.pi_desc) / 100));
				break;
			}

			store.setValue(item, "pi_valort", item.pi_quant * item.pi_valor);

			orderTotal();
		};
	
		//Refresh the data store for the groups dropdown (in case groups added, edited or deleted)
		function refreshGroupDropDown(group) {
			groupsRest.query("/nodes")
				.then(function (response) {
					dijit.byId("edit_client_cf_grupo").store = new Memory({
						data: response
					});
					if (group) {
						dijit.byId("edit_client_cf_grupo").set("value", group);
					}
				});
		}
	
		function refreshClientData(callback) {
			// Load required data only one time
			if (loadClientsData === false) {
				callback();
				return;
			}
			loadClientsData = false;

			var state, receiving, transporter;
			state = false;
			receiving = false;
			transporter = false;
			

			// Rest store for states
			statesRest = new JsonRest({target: "/representante/rest/states"}).get().then(function (response) {
				dijit.byId("edit_client_ed_estado").store = new Memory({
					idProperty: "es_codigo",
					data: response
				});
				dijit.byId("edit_client_ee_estado").store = new Memory({
					idProperty: "es_codigo",
					data: response
				});
				dijit.byId("edit_client_ec_estado").store = new Memory({
					idProperty: "es_codigo",
					data: response
				});

				state = true;
				if (state && receiving && transporter) {
					callback();
				}
			});

			// Rest store for receiving terms
			receivingRest = new JsonRest({target: "/representante/rest/receiving"}).get().then(function (response) {
				dijit.byId("edit_client_cf_receb").store = new Memory({
					idProperty: "ct_codigo",
					data: response
				});

				receiving = true;
				if (state && receiving && transporter) {
					callback();
				}
			});


			// Rest store for transporters
			transportersRest = new JsonRest({target: "/representante/rest/transporters"}).get().then(function (response) {
				dijit.byId("edit_client_cf_transp").store = new Memory({
					idProperty: "tr_codigo",
					data: response
				});

				transporter = true;
				if (state && receiving && transporter) {
					callback();
				}
			});
		}
	
		function refreshOrderData(callback) {
			// Load required data only one time
			if (loadOrdersData === false) {
				callback();
				return;
			}
			loadOrdersData = false;

			var product, receiving, transporter;
			product = false;
			receiving = false;
			transporter = false;
			
			// Rest store for products
			productsRest = new JsonRest({target: "/representante/rest/products"}).get().then(function (response) {
				productsMemory = new Memory({
					idProperty: "pr_codigo",
					data: response
				});

				itensGrid.layout.cells[1].widgetProps.store = productsMemory;

				product = true;
				if (product && receiving && transporter) {
					callback();
				}
			});


			// Rest store for receiving terms
			receivingRest = new JsonRest({target: "/representante/rest/receiving"}).get().then(function (response) {
				dijit.byId("edit_order_pe_receb").store = new Memory({
					idProperty: "ct_codigo",
					data: response
				});

				receiving = true;
				if (product && receiving && transporter) {
					callback();
				}
			});

			// Rest store for transporters
			transportersRest = new JsonRest({target: "/representante/rest/transporters"}).get().then(function (response) {
				dijit.byId("edit_order_pe_transp").store = new Memory({
					idProperty: "tr_codigo",
					data: response
				});

				transporter = true;
				if (product && receiving && transporter) {
					callback();
				}
			});
		}

		// Refresh client data section
		function refreshDataSection(newPage) {
			var client, page;

			client = clientsGrid.selection.getSelected()[0];
			if (client) {
				mnuNewOrder.set("disabled", false);
			} else {
				mnuNewOrder.set("disabled", true);
			}

			page = newPage || dataSection.selectedChildWidget;
			switch (page.id) {
			case "clientData":
				//Refresh the data for the currently selected client
				if (selectedDataClient === client) {
					return;
				}
				selectedDataClient = client;

				if (client) {
					clientData.set("href", "/representante/ajax/client.fxp?" + client.cf_codigo);
				} else {
					clientData.set("content", "<em>Selecione um cliente para consultar informações</em>");
				}
				break;
			case "orderData":
				//Refresh the orders datagrid to display orders for the currently selected client
				if (selectedOrderClient === client) {
					return;
				}
				selectedOrderClient = client;

				if (client) {
					ordersGrid.setQuery("/" +  client.cf_codigo);
				} else {
					ordersGrid.setQuery("");
				}
				ordersGrid.selection.clear();

				mnuEditOrder.set("disabled", true);
				mnuDeleteOrder.set("disabled", true);
				ctxMnuEditOrder.set("disabled", true);
				ctxMnuDeleteOrder.set("disabled", true);
				break;
			case "billData":
				//Refresh the billData datagrid to display bills for the currently selected client
				if (selectedBillClient === client) {
					return;
				}
				selectedBillClient = client;

				if (client) {
					billsGrid.setQuery("/" +  client.cf_pess);
				} else {
					billsGrid.setQuery("");
				}
				billsGrid.selection.clear();

				break;
			}
		}
			
		//Refresh the data grid to display clients for the currently selected group
		function refreshClientsGrid(group) {
			clientsGrid.setQuery("/" +  group.id);
			clientsGrid.selection.clear();

			mnuEditClient.set("disabled", true);
			mnuMoveClient.set("disabled", true);
			mnuDeleteClient.set("disabled", true);
			ctxMnuEditClient.set("disabled", true);
			ctxMnuMoveClient.set("disabled", true);
			ctxMnuDeleteClient.set("disabled", true);

			refreshDataSection();
		}

		//Update the data grid to display itens for the currently selected order
		function refreshItensGrid(item) {
			if (item) {
				itensGrid.setQuery("/" + item.pe_codigo);
			} else {
				itensGrid.setQuery("");
			}
		}

		// Ok dialog object
		okDialogMsg = dom.byId("okDialogMessage");

		//This function creates a confirm dialog box which calls a given callback
		//function with a true or false argument when OK or Cancel is pressed.
		function confirmDialog(title, body, callbackFn) {
            var theDialog, callback, message, btnsDiv, okBtn, cancelBtn;
            
			theDialog = new Dialog({
				id: "confirmDialog",
				title: title,
				draggable: false,

				onHide: function () {
					theDialog.destroyRecursive();
				}
			});

			callback = function (mouseEvent) {
				var srcEl = mouseEvent.srcElement || mouseEvent.target;

				if (srcEl.value === "OK") {
					callbackFn(true);
				} else {
					callbackFn(false);
				}

				theDialog.hide();
			};

			message = dojo.create("p", {
				style: {
					marginTop: "5px"
				},
				innerHTML: body
			});

			btnsDiv = dojo.create("div", {
				style: {
					textAlign: "center"
				}
			});

			okBtn = new Button({label: "OK", id: "confirmDialogOKButton", onClick: callback, value: "OK" });
			cancelBtn = new Button({label: "Cancel", id: "confirmDialogCancelButton", onClick: callback });

			theDialog.containerNode.appendChild(message);
			theDialog.containerNode.appendChild(btnsDiv);

			btnsDiv.appendChild(okBtn.domNode);
			btnsDiv.appendChild(cancelBtn.domNode);

			theDialog.show();
		}

		//Process the adding of a new group to the database
		//function doNewGroup(e) {
		//	e.preventDefault();
		//	e.stopPropagation();
		//	if (this.isValid()) {
		//		groupsRest.add(dojo.formToObject("newGroupForm")).then(function (data) {
		//			if (data.success) {
		//				groupsTree.refreshTree();
		//
		//				okDialog.set("title", "Grupo criado com successo");
		//				okDialogMsg.innerHTML = "O grupo <strong>" +  data.name +  "</strong> foi criado com sucesso.";
		//
		//				newGroupDialog.hide();
		//				okDialog.show();
		//			} else {
		//				okDialog.set("title", "Erro criando o grupo");
		//				okDialogMsg.innerHTML = data.error;
		//				okDialog.show();
		//			}
		//		});
		//	}
		//}

		//Process the editing of an existing group in the database
		//function doEditGroup(e) {
		//	e.preventDefault();
		//	e.stopPropagation();
		//	if (this.isValid()) {
		//		groupsRest.put(dojo.formToObject("editGroupForm")).then(function (data) {
		//			if (data.success) {
		//				groupsModel.onChange(data);
		//
		//				okDialog.set("title", "Grupo renomeado com sucesso");
		//				okDialogMsg.innerHTML = "O grupo <strong>" +  data.name +  "</strong> foi renomeado com sucesso.";
		//
		//				editGroupDialog.hide();
		//				okDialog.show();
		//			} else {
		//				okDialog.set("title", "Erro renomeando o grupo");
		//				okDialogMsg.innerHTML = data.error;
		//				okDialog.show();
		//			}
		//		});
		//	}
		//}

		//Configures the "Rename Group" dialog for the selected group
		//function renameGroup() {
        //   var group, groupId, groupName;
		//	group = groupsTree.get("selectedItem");
		//	groupId = group.id;
		//	groupName = group.name;
		//
		//	dom.byId("edit_group_id").value = groupId;
		//	dijit.byId("edit_group_old").set("value", groupName);
		//	editGroupDialog.show();
		//}

		//Process the editing of an existing group in the database
		//function deleteGroup() {
		//	confirmDialog("Confirme a exclusão", "Confirma a exclusão do grupo?", function (btn) {
		//		if (btn) {
		//			var group = groupsTree.get("selectedItem");
		//			groupsRest.remove(group.id).then(function (data) {
		//				if (data.success) {
		//					groupsModel.onDelete({id: group.id});
		//
		//					okDialog.set("title", "Grupo excluído com sucesso");
		//					okDialogMsg.innerHTML = "O grupo <strong>" +  data.name +  "</strong> foi excluído com sucesso.";
		//					editGroupDialog.hide();
		//					okDialog.show();
		//				} else {
		//					okDialog.set("title", "Erro excluindo o grupo");
		//					okDialogMsg.innerHTML = data.error;
		//					okDialog.show();
		//				}
		//			});
		//		}
		//	});
		//}

		//Clears the "Edit client" form, sets it up for adding a new client
		function newClient() {
			refreshClientData(function () {
				refreshGroupDropDown();

				dijit.byId("edit_client_cf_codigo").set("value", "new");
				dijit.byId("edit_client_cf_grupo").reset();
				dijit.byId("edit_client_pe_nome").reset();
				dijit.byId("edit_client_pe_tipo").reset();
				dijit.byId("edit_client_ed_lograd").reset();
				dijit.byId("edit_client_ed_numero").reset();
				dijit.byId("edit_client_ed_compl").reset();
				dijit.byId("edit_client_ed_bairro").reset();
				dijit.byId("edit_client_ed_cidade").reset();
				dijit.byId("edit_client_ed_estado").reset();
				dijit.byId("edit_client_ed_cep").reset();
				dijit.byId("edit_client_ed_mv_ibge").reset();
				dijit.byId("edit_client_cf_contato").reset();
				dijit.byId("edit_client_ed_tel_loc").reset();
				dijit.byId("edit_client_ed_tel_rec").reset();
				dijit.byId("edit_client_ed_tel_fin").reset();
				dijit.byId("edit_client_pe_tel_cel").reset();
				dijit.byId("edit_client_pe_radio").reset();
				dijit.byId("edit_client_pe_email").reset();
				dijit.byId("edit_client_pe_cpf").reset();
				dijit.byId("edit_client_pe_rg_num").reset();
				dijit.byId("edit_client_pe_rg_emi").reset();
				dijit.byId("edit_client_pe_rg_dte").reset();
				dijit.byId("edit_client_pe_psp_num").reset();
				dijit.byId("edit_client_pe_cnpj").reset();
				dijit.byId("edit_client_pe_ie").reset();
				dijit.byId("edit_client_pe_im").reset();
				dijit.byId("edit_client_pe_suframa").reset();
				dijit.byId("edit_client_cf_mreceb").reset();
				dijit.byId("edit_client_cf_receb").reset();
				dijit.byId("edit_client_cf_transp").reset();
				dijit.byId("edit_client_ee_lograd").reset();
				dijit.byId("edit_client_ee_numero").reset();
				dijit.byId("edit_client_ee_compl").reset();
				dijit.byId("edit_client_ee_bairro").reset();
				dijit.byId("edit_client_ee_cidade").reset();
				dijit.byId("edit_client_ee_estado").reset();
				dijit.byId("edit_client_ee_cep").reset();
				dijit.byId("edit_client_ee_mv_ibge").reset();
				dijit.byId("edit_client_ee_tel_loc").reset();
				dijit.byId("edit_client_ec_lograd").reset();
				dijit.byId("edit_client_ec_numero").reset();
				dijit.byId("edit_client_ec_compl").reset();
				dijit.byId("edit_client_ec_bairro").reset();
				dijit.byId("edit_client_ec_cidade").reset();
				dijit.byId("edit_client_ec_estado").reset();
				dijit.byId("edit_client_ec_cep").reset();
				dijit.byId("edit_client_ec_mv_ibge").reset();
				dijit.byId("edit_client_ec_tel_loc").reset();
				dijit.byId("edit_client_cf_obs").reset();
				dijit.byId("edit_client_cf_obscv").reset();

				dijit.byId("editClientDialog").set("title", "Novo cliente");
				dijit.byId("editClientDialog").show();
			});
		}

		//Populates "Edit Client" form with selected client's data
		function editClient() {
			refreshClientData(function () {
				var cf_codigo = clientsGrid.selection.getSelected()[0].cf_codigo;

				clientRest.get(cf_codigo).then(function (client) {
					refreshGroupDropDown(client.cf_grupo);

					dijit.byId("edit_client_cf_codigo").set("value", client.cf_codigo);
					dijit.byId("edit_client_pe_nome").set("value", client.pe_nome);
					dijit.byId("edit_client_pe_tipo").set("value", client.pe_tipo);
					dijit.byId("edit_client_ed_lograd").set("value", client.ed_lograd);
					dijit.byId("edit_client_ed_numero").set("value", client.ed_numero);
					dijit.byId("edit_client_ed_compl").set("value", client.ed_compl);
					dijit.byId("edit_client_ed_bairro").set("value", client.ed_bairro);
					dijit.byId("edit_client_ed_cidade").set("value", client.ed_cidade);
					dijit.byId("edit_client_ed_estado").set("value", client.ed_estado);
					dijit.byId("edit_client_ed_cep").set("value", client.ed_cep);
					dijit.byId("edit_client_ed_mv_ibge").set("value", client.ed_mv_ibge);
					dijit.byId("edit_client_cf_contato").set("value", client.cf_contato);
					dijit.byId("edit_client_ed_tel_loc").set("value", client.ed_tel_loc);
					dijit.byId("edit_client_ed_tel_rec").set("value", client.ed_tel_rec);
					dijit.byId("edit_client_ed_tel_fin").set("value", client.ed_tel_fin);
					dijit.byId("edit_client_pe_tel_cel").set("value", client.pe_tel_cel);
					dijit.byId("edit_client_pe_radio").set("value", client.pe_radio);
					dijit.byId("edit_client_pe_email").set("value", client.pe_email);
					dijit.byId("edit_client_pe_cpf").set("value", client.pe_cpf);
					dijit.byId("edit_client_pe_rg_num").set("value", client.pe_rg_num);
					dijit.byId("edit_client_pe_rg_emi").set("value", client.pe_rg_emi);
					dijit.byId("edit_client_pe_rg_dte").set("value", client.pe_rg_dte);
					dijit.byId("edit_client_pe_psp_num").set("value", client.pe_psp_num);
					dijit.byId("edit_client_pe_cnpj").set("value", client.pe_cnpj);
					dijit.byId("edit_client_pe_ie").set("value", client.pe_ie);
					dijit.byId("edit_client_pe_im").set("value", client.pe_im);
					dijit.byId("edit_client_pe_suframa").set("value", client.pe_suframa);
					dijit.byId("edit_client_cf_mreceb").set("value", client.cf_mreceb);
					dijit.byId("edit_client_cf_receb").set("value", client.cf_receb);
					dijit.byId("edit_client_cf_transp").set("value", client.cf_transp);
					dijit.byId("edit_client_ee_lograd").set("value", client.ee_lograd);
					dijit.byId("edit_client_ee_numero").set("value", client.ee_numero);
					dijit.byId("edit_client_ee_compl").set("value", client.ee_compl);
					dijit.byId("edit_client_ee_bairro").set("value", client.ee_bairro);
					dijit.byId("edit_client_ee_cidade").set("value", client.ee_cidade);
					dijit.byId("edit_client_ee_estado").set("value", client.ee_estado);
					dijit.byId("edit_client_ee_cep").set("value", client.ee_cep);
					dijit.byId("edit_client_ee_mv_ibge").set("value", client.ee_mv_ibge);
					dijit.byId("edit_client_ee_tel_loc").set("value", client.ee_tel_loc);
					dijit.byId("edit_client_ec_lograd").set("value", client.ec_lograd);
					dijit.byId("edit_client_ec_numero").set("value", client.ec_numero);
					dijit.byId("edit_client_ec_compl").set("value", client.ec_compl);
					dijit.byId("edit_client_ec_bairro").set("value", client.ec_bairro);
					dijit.byId("edit_client_ec_cidade").set("value", client.ec_cidade);
					dijit.byId("edit_client_ec_estado").set("value", client.ec_estado);
					dijit.byId("edit_client_ec_cep").set("value", client.ec_cep);
					dijit.byId("edit_client_ec_mv_ibge").set("value", client.ec_mv_ibge);
					dijit.byId("edit_client_ec_tel_loc").set("value", client.ec_tel_loc);
					dijit.byId("edit_client_cf_obs").set("value", client.cf_obs);
					dijit.byId("edit_client_cf_obscv").set("value", client.cf_obscv);

					dijit.byId("editClientDialog").set("title", "Editar cliente");
					dijit.byId("editClientDialog").show();
				});
			});
		}

		//Process the editing of an existing client in the database
		function doEditClient(e) {
			e.preventDefault();
			e.stopPropagation();
			if (this.isValid()) {
				clientRest.put(editClientForm.getValues()).then(function (data) {
					if (data.success) {
						if (data.new_client) {
							okDialog.set("title", "Cliente incluído com sucesso");
							okDialogMsg.innerHTML = "O cliente foi incluído com sucesso.";
						} else {
							okDialog.set("title", "Cliente alterado com sucesso");
							okDialogMsg.innerHTML = "O cliente foi alterado com sucesso.";
						}

						var treeSel, group;
						treeSel = groupsTree.get("selectedItem");
						if (treeSel) {
							group = treeSel;
						} else {
							group = { id: 0 };
						}
						refreshClientsGrid(group);

						editClientDialog.hide();
						okDialog.show();
					} else {
						if (data.new_client) {
							okDialog.set("title", "Erro incluindo o cliente");
						} else {
							okDialog.set("title", "Erro alterando o cliente");
						}
						okDialogMsg.innerHTML = data.error;
						okDialog.show();
					}
				});
			}
		}

		//Opens and configures the "Move client" dialog
		function moveClient() {
			var client = clientsGrid.selection.getSelected()[0];
		
			dijit.byId("move_client_id").set("value", client.cf_codigo);
			dijit.byId("move_client_name").set("value", client.pe_nome);

			groupsRest.query("/nodes")
				.then(function (response) {
					dijit.byId("move_client_group").store = new Memory({
						data: response
					});
					if (client.cf_grupo) {
						dijit.byId("move_client_group").set("value", Number(client.cf_grupo));
					} else {
						dijit.byId("move_client_group").reset();
					}
					dijit.byId("moveClientDialog").show();
				});
		}

		//Process the moving of a client to a different group in the database
		function doMoveClient(e) {
			e.preventDefault();
			e.stopPropagation();
			if (this.isValid()) {
				clientRest.put(moveClientForm.getValues()).then(function (data) {
					if (data.success) {
						okDialog.set("title", "Cliente movido com sucesso");
						okDialogMsg.innerHTML = "O cliente foi movido com sucesso.";

						var treeSel, group;
						treeSel = groupsTree.get("selectedItem");
						if (treeSel) {
							group = treeSel;
						} else {
							group = { id: 0 };
						}
						refreshClientsGrid(group);
						
						moveClientDialog.hide();
						okDialog.show();
					} else {
						okDialog.set("title", "Erro movendo o cliente");
						okDialogMsg.innerHTML = data.error;
						okDialog.show();
					}
				});
			}
		}

		//Displays a dialog box asking to confirm deletion of client. Deletes if OK is pressed.
		function deleteClient() {
			confirmDialog("Confirma a exclusão", "Confirma a exclusão do cliente?", function (btn) {
				if (btn) {
					var client, clientId, clientName;
					client = clientsGrid.selection.getSelected()[0];
					clientId = client.cf_codigo;
					clientName = client.pe_nome.trim();

					clientRest.remove(clientId).then(function (data) {
						if (data.success) {
							var treeSel, group;
							treeSel = groupsTree.get("selectedItem");
							if (treeSel) {
								group = treeSel;
							} else {
								group = { id: 0 };
							}
							refreshClientsGrid(group);

							okDialog.set("title", "Cliente excluído com sucesso");
							okDialogMsg.innerHTML = "O cliente <strong>" +  clientName +  "</strong> foi excluído com sucesso.";
							okDialog.show();
						} else {
							okDialog.set("title", "Erro excluindo o cliente");
							okDialogMsg.innerHTML = data.error;
							okDialog.show();
						}
					});
				}
			});
		}

		//Clears the "Edit order" form, sets it up for adding a new order
		function newOrder() {
			refreshOrderData(function () {
				refreshItensGrid();

				itensCounter = 1;

				var client = clientsGrid.selection.getSelected()[0];

				clientRest.get(client.cf_codigo).then(function (client) {
					dijit.byId("edit_order_pe_codigo").set("value", "new");
					dijit.byId("edit_order_pe_pedido").reset();
					dijit.byId("edit_order_pe_clifor").set("value", client.cf_codigo);
					dijit.byId("edit_order_pe_mreceb").set("value", client.cf_mreceb);
					dijit.byId("edit_order_pe_receb").set("value", client.cf_receb);
					dijit.byId("edit_order_pe_situac").set("value", 1);
					dijit.byId("edit_order_pe_nome").set("value", client.pe_nome);
					dijit.byId("edit_order_pe_data").set("value", new Date());
					dijit.byId("edit_order_pe_datent").set("value", new Date(new Date().getTime() + 86400000));
					dijit.byId("edit_order_pe_cobr").set("value", new Date(new Date().getTime() + 86400000));
					dijit.byId("edit_order_pe_numped").reset();
					dijit.byId("edit_order_pe_numven").reset();
					dijit.byId("edit_order_pe_transp").set("value", client.cf_transp);
					dijit.byId("edit_order_pe_obs").set("value", client.cf_obscv);
					dijit.byId("edit_order_pe_valor").set("value", 0);
					dijit.byId("edit_order_pe_acres").set("value", 0);
					dijit.byId("edit_order_pe_desc").set("value", 0);
					dijit.byId("edit_order_pe_valort").set("value", 0);

					dijit.byId("edit_order_pe_receb").set("readOnly", false);
					dijit.byId("edit_order_pe_mreceb").set("readOnly", false);
					dijit.byId("edit_order_pe_acres").set("readOnly", false);
					dijit.byId("edit_order_pe_desc").set("readOnly", false);

					editOrderAddItem.set("disabled", false);
					editOrderDeleteItem.set("disabled", false);
					editOrderSubmit.set("disabled", false);

					dijit.byId("editOrderDialog").set("title", "Novo pedido");
					dijit.byId("editOrderDialog").show();
				});
			});
		}

		//Populates "Edit Order" form with selected order's data
		function editOrder() {
			refreshOrderData(function () {
				var order = ordersGrid.selection.getSelected()[0];

				orderRest.get(order.pe_codigo).then(function (order) {
					itensCounter = 1;

					refreshItensGrid(order);

					dijit.byId("edit_order_pe_codigo").set("value", order.pe_codigo);
					dijit.byId("edit_order_pe_pedido").set("value", order.pe_pedido);
					dijit.byId("edit_order_pe_clifor").set("value", order.pe_clifor);
					dijit.byId("edit_order_pe_receb").set("value", order.pe_receb);
					dijit.byId("edit_order_pe_mreceb").set("value", order.pe_mreceb);
					dijit.byId("edit_order_pe_situac").set("value", order.pe_situac);
					dijit.byId("edit_order_pe_nome").set("value", order.pe_nome);
					dijit.byId("edit_order_pe_data").set("value", order.pe_data);
					dijit.byId("edit_order_pe_datent").set("value", order.pe_datent);
					dijit.byId("edit_order_pe_cobr").set("value", order.pe_cobr);
					dijit.byId("edit_order_pe_numped").set("value", order.pe_numped);
					dijit.byId("edit_order_pe_numven").set("value", order.pe_numven);
					dijit.byId("edit_order_pe_transp").set("value", order.pe_transp);
					dijit.byId("edit_order_pe_obs").set("value", order.pe_obs);
					dijit.byId("edit_order_pe_valor").set("value", order.pe_valor);
					dijit.byId("edit_order_pe_acres").set("value", order.pe_acres);
					dijit.byId("edit_order_pe_desc").set("value", order.pe_desc);
					dijit.byId("edit_order_pe_valort").set("value", order.pe_valort);

					dijit.byId("edit_order_pe_receb").set("readOnly", order.pe_situac  !== 1);
					dijit.byId("edit_order_pe_mreceb").set("readOnly", order.pe_situac !== 1);
					dijit.byId("edit_order_pe_acres").set("readOnly", order.pe_situac !== 1);
					dijit.byId("edit_order_pe_desc").set("readOnly", order.pe_situac !== 1);

					editOrderAddItem.set("disabled", order.pe_situac !== 1);
					editOrderDeleteItem.set("disabled", order.pe_situac !== 1);
					editOrderSubmit.set("disabled", order.pe_situac !== 1);
					
					dijit.byId("editOrderDialog").set("title", "Editar pedido");
					dijit.byId("editOrderDialog").show();
				});
			});
		}

		//Displays a dialog box asking to confirm deletion of order. Deletes if OK is pressed.
		function deleteOrder() {
			confirmDialog("Confirma a exclusão", "Confirma a exclusão do pedido?", function (btn) {
				if (btn) {
					var order, orderId, orderNumber;
					order = ordersGrid.selection.getSelected()[0];
					orderId = order.pe_codigo;
					orderNumber = order.pe_pedido.trim();

					orderRest.remove(orderId).then(function (data) {
						if (data.success) {
							selectedOrderClient = undefined;
							refreshDataSection();

							okDialog.set("title", "Pedido excluído com sucesso");
							okDialogMsg.innerHTML = "O pedido <strong>" +  orderNumber +  "</strong> foi excluído com sucesso.";
							okDialog.show();
						} else {
							okDialog.set("title", "Erro excluindo o pedido");
							okDialogMsg.innerHTML = data.error;
							okDialog.show();
						}
					});
				}
			});
		}

		//Process the editing of an existing order in the database
		function doEditOrder(e) {
			e.preventDefault();
			e.stopPropagation();
			if (this.isValid()) {
				var orderData, i;
				orderData = editOrderForm.getValues();
				
				orderData.Itens = [];
				for (i = 0; i < itensGrid.rowCount; i = i + 1) {
					orderData.Itens.push(itensGrid.getItem(i));
				}
				
				orderRest.put(orderData).then(function (data) {
					if (data.success) {
						if (data.new_order) {
							okDialog.set("title", "Pedido incluído com sucesso");
							okDialogMsg.innerHTML = "Pedido <strong>" + data.new_order + "</strong> foi incluído com sucesso.";
						} else {
							okDialog.set("title", "Pedido alterado com sucesso");
							okDialogMsg.innerHTML = "O pedido foi alterado com sucesso.";
						}

						selectedOrderClient = undefined;
						refreshDataSection();

						editOrderDialog.hide();
						okDialog.show();
					} else {
						if (data.new_order) {
							okDialog.set("title", "Erro incluindo o pedido.");
						} else {
							okDialog.set("title", "Erro alterando o pedido.");
						}
						okDialogMsg.innerHTML = data.error;
						okDialog.show();
					}
				});
			}
		}
	
		//Display client data in main preview pane			
		function selectClient(evt) {
			mnuEditClient.set("disabled", false);
			mnuMoveClient.set("disabled", false);
			mnuDeleteClient.set("disabled", false);
			ctxMnuEditClient.set("disabled", false);
			ctxMnuMoveClient.set("disabled", false);
			ctxMnuDeleteClient.set("disabled", false);

			refreshDataSection();
		}

		//Display order data in main preview pane			
		function selectOrder(evt) {
			mnuEditOrder.set("disabled", false);
			mnuDeleteOrder.set("disabled", false);
			ctxMnuEditOrder.set("disabled", false);
			ctxMnuDeleteOrder.set("disabled", false);
		}

		// Add an item to order
		function addItem() {
			var order = ordersGrid.selection.getSelected()[0];

			itensStore.newItem({
				pi_codigo: "new" + itensCounter,
				pi_pedido: order ? order.pe_codigo : "new",
				pi_prod: "",
				pi_quant: 0,
				pi_moeda: "R$",
				pi_preco: 0,
				pi_valor: 0,
				pi_desc: 0,
				pi_valort: 0,
				pr_descr: "",
				pr_unid: ""
			});
			
			itensCounter = itensCounter + 1;
		}

		// Delete selected order item
		function deleteItem() {
			var item = itensGrid.selection.getSelected()[0];
			
			if (item) {
				itensStore.deleteItem(item);
			} else {
				okDialog.set("title", "Atenção");
				okDialogMsg.innerHTML = "Selecione o item antes de excluir.";
				okDialog.show();
			}
		}

		//When a user selects a node in tree, enable/disable menus and reload clients data grid
		function selectNode(e) {
			var item = dijit.getEnclosingWidget(e.target).item;
			if (item !== undefined) {
				groupsTree.set("selectedItem", item);
				//if (item.id !== 0) {
				//	mnuRenameGroup.set("disabled", false);
				//	mnuDeleteGroup.set("disabled", false);
				//	ctxMnuRenameGroup.set("disabled", false);
				//	ctxMnuDeleteGroup.set("disabled", false);
				//} else {
				//	mnuRenameGroup.set("disabled", true);
				//	mnuDeleteGroup.set("disabled", true);
				//	ctxMnuRenameGroup.set("disabled", true);
				//	ctxMnuDeleteGroup.set("disabled", true);
				//}
				refreshClientsGrid(item);
			}
		}

		// Startup
		function startup() {
			// Run parser
			parser.parse();

			// Apply masks
			$("#edit_client_ed_cep").inputmask("99999-999");
			$("#edit_client_ed_tel_loc").inputmask("(99) 9999-9999");
			$("#edit_client_ed_tel_rec").inputmask("(99) 9{4,5}-9999");
			$("#edit_client_ed_tel_fin").inputmask("(99) 9{4,5}-9999");
			$("#edit_client_pe_tel_cel").inputmask("(99) 9{4,5}-9999");
			$("#edit_client_pe_cpf").inputmask("999.999.999-99");
			$("#edit_client_pe_cnpj").inputmask("999.999.999/9999-99");
			$("#edit_client_ee_cep").inputmask("99999-999");
			$("#edit_client_ee_tel_loc").inputmask("(99) 9999-9999");
			$("#edit_client_ec_cep").inputmask("99999-999");
			$("#edit_client_ec_tel_loc").inputmask("(99) 9999-9999");
	
			// Tree refresh workaround
			groupsTree.refreshTree = function () {
				this.dndController.selectNone(); // As per the answer below     
				
				// Force model to requery
				this.model.root = null;
				
				// Completely delete every node from the dijit.Tree     
				this._itemNodesMap = {};
				this.rootNode.state = "UNCHECKED";
			
				// Destroy the widget
				this.rootNode.destroyRecursive();
			
				// Recreate the model, (with the model again)
				this.model.constructor(this.model);
			
				// Rebuild the tree
				this.postMixInProperties();
				this._load();
			};

			// Edit itensGrid bug workaround
			itensGrid.doApplyCellEdit = function (inValue, inRowIndex, inAttrName) {
				var item = itensGrid.getItem(inRowIndex);
				this.store.setValue(item, inAttrName, inValue);
				this.onApplyCellEdit(inValue, inRowIndex, inAttrName);
			};

			//Select tree node and reload clients data grid when a user clicks on a node in the groups tree
			groupsTree.on("MouseDown", selectNode);
			
			//Display client data on datarid selection
			clientsGrid.on("RowClick", selectClient);

			//Display order data on datagrid selection
			ordersGrid.on("RowClick", selectOrder);
	
			//Update data section
			dojo.connect(dataSection, "_transition", function (newPage, oldPage) {
				if (newPage !== oldPage) {
					refreshDataSection(newPage);
				}
			});
			
			//Menus
			mnuLogout.on("Click", function (e) {
				var logout = new JsonRest({target: "/representante/rest"});
				logout.get("logout").then(function () {
					window.location.href = "/representante/";
				});
			});
	
			//New group
			//mnuNewGroup.on("Click", function (e) { newGroupDialog.show(); });
	
			//Rename group
			//mnuRenameGroup.on("Click", renameGroup);
			//ctxMnuRenameGroup.on("Click", renameGroup);
	
			//Delete group
			//mnuDeleteGroup.on("Click", deleteGroup);
			//ctxMnuDeleteGroup.on("Click", deleteGroup);
	
			//New client
			mnuNewClient.on("Click", newClient);
	
			//Edit client
			mnuEditClient.on("Click", editClient);
			ctxMnuEditClient.on("Click", editClient);
	
			//Move client
			mnuMoveClient.on("Click", moveClient);
			ctxMnuMoveClient.on("Click", moveClient);
	
			//Delete client
			mnuDeleteClient.on("Click", deleteClient);
			ctxMnuDeleteClient.on("Click", deleteClient);
			
			//New order
			mnuNewOrder.on("Click", newOrder);
	
			//Edit order
			mnuEditOrder.on("Click", editOrder);
			ctxMnuEditOrder.on("Click", editOrder);
	
			
			//Delete client
			mnuDeleteOrder.on("Click", deleteOrder);
			ctxMnuDeleteOrder.on("Click", deleteOrder);
			
			//Dialog boxes
	
			//New group
			//newGroupDialog.on("Show", function (e) {dijit.byId("new_group_name").reset(); });
			//newGroupForm.on("Submit", doNewGroup);
			//newGroupCancel.on("Click", function (e) {newGroupDialog.hide(); });
	
			//Edit group
			//editGroupDialog.on("Show", function (e) {dijit.byId("edit_group_name").reset(); });
			//editGroupForm.on("Submit", doEditGroup);
			//editGroupCancel.on("Click", function (e) {editGroupDialog.hide(); });
	
			//Edit client
			editClientForm.on("Submit", doEditClient);
			editClientCancel.on("Click", function () {editClientDialog.hide(); });
	
			moveClientForm.on("Submit", doMoveClient);
			moveClientCancel.on("Click", function () {moveClientDialog.hide(); });

			//Edit order
			editOrderAddItem.on("Click", addItem);
			editOrderDeleteItem.on("Click", deleteItem);

			editOrderForm.on("Submit", doEditOrder);
			editOrderCancel.on("Click", function () {editOrderDialog.hide(); });
		
			//OK dialog ok button
			okDialogOK.on("Click", function () {okDialog.hide(); });

			// Fields triggers
			dijit.byId('edit_order_pe_desc').on('blur', orderTotal);
			dijit.byId('edit_order_pe_acres').on('blur', orderTotal);
			
			// Hide loading overlay
			endLoading();
		}
		
		// Hide loading overlay
		function endLoading() {
			baseFx.fadeOut({
				node: dom.byId("loadingOverlay"),
				onEnd: function (node) {
					domStyle.set(node, "display", "none");
				}
			}).play();
		}

		formatPercentage = function (inDatum) {
			return isNaN(inDatum) ? "..." : dojo.number.format(inDatum / 100, {pattern: "##0.0# %"});
		};
	
		formatCurrency = function (inDatum) {
			return isNaN(inDatum) ? "..." : currency.format(inDatum, {currency: "R$ "});
		};
		
		formatDate = function (inDatum) {
			return locale.format(new Date(inDatum), {selector: "date", fullYear: true});
		};

		formatProduct = function (inDatum) {
			var item;
			item = productsMemory.get(inDatum);
			return item ? item.pr_descr : "<span class='dojoxGridNoData'>NÃO DISPONÍVEL</span>";
		};
	

		return {
			init: function () {
				startup();
			}
		};
	});