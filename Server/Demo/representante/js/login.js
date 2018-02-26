/*jslint sloppy: true*/

/*globals
define:true, domGeometry:true,
showLogin:true, loginOk:true, loginCancel:true,
endLoading:true, okDialog:true, okDialogOK:true
*/

define([
	"dojo/dom",
	"dojo/dom-style",
	"dojo/_base/fx",
	"dijit/registry",
	"dijit/Dialog",
	"dijit/form/Form",
	"dijit/form/Button",
	"dijit/form/CheckBox",
	"dijit/form/TextBox",
	"dojo/store/JsonRest",
	"dojo/parser"
],
	function (dom, domStyle, baseFx, registry, Dialog, Form, Button, CheckBox, TextBox, JsonRest, parser) {
		// Run parser
		parser.parse();

		// Startup
		function startup() {
			showLogin();
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

		// Show loading overlay
		function startLoading(targetNode) {
			var overlayNode, coords;
			overlayNode = dom.byId("loadingOverlay");
			if ("none" === domStyle.get(overlayNode, "display")) {
				coords = domGeometry.getMarginBox(targetNode || document.body);
				domGeometry.setMarginBox(overlayNode, coords);

				domStyle.set(dom.byId("loadingOverlay"), {
					display: "block",
					opacity: 1
				});
			}
		}

		// Ok dialog object
		var okDialogMsg = dom.byId("okDialogMessage");
		
		// Show the login
		function showLogin() {
			registry.byId("login").show();
		}

		// Query username and verify  password
		function doLogin() {
			var username, password, keepconnection, login, user;
			username = registry.byId("username");
			password = registry.byId("password");
			keepconnection = registry.byId("keepconnection");
			
			login = new JsonRest({target: "/representante/rest/login"});
			user = login.get(window.btoa(username.value) + "&" + window.btoa(password.value) + "&" + keepconnection.checked)
				.then(function (data) {
					if (data.success) {
						registry.byId("login").hide();
						location.reload(true);
					} else {
						okDialog.set("title", "Erro");
						okDialogMsg.innerHTML = "Usuário ou senha inválidos.";
						okDialog.show();
					}
				});
		}

		// Cancel the login
		function cancelLogin() {
			registry.byId("login").hide();
			history.back();
		}

		//Login buttons
		loginOk.on("Click", doLogin);
		loginCancel.on("Click", cancelLogin);

		//OK dialog ok button
		okDialogOK.on("Click", function (e) {okDialog.hide(); });

		return {
			init: function () {
				startup();
			}
		};
	});