import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

// Bridges the native navigation bar's hamburger button to the existing web nav
// menu. This "menu" component is only rendered inside the native apps (see
// shared/_native_menu). On connect it tells the native side to add a bar button;
// when that button is tapped the native component replies, firing the callback
// here which toggles the sibling `nav-menu` Stimulus controller's panel.
//
// It shares its element with `nav-menu`, so the same open/close logic (and the
// same links) power both the web header and the native menu.
export default class extends BridgeComponent {
  static component = "menu"

  connect() {
    super.connect()
    this.send("connect", { title: "Menu" }, () => this.toggleMenu())
  }

  toggleMenu() {
    const menu = this.navMenu
    if (!menu) return
    menu.isOpen() ? menu.close() : menu.open()
  }

  get navMenu() {
    return this.application.getControllerForElementAndIdentifier(this.element, "nav-menu")
  }
}
