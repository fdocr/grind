import { Controller } from "@hotwired/stimulus"
import { createEmbedMap } from "lib/leaflet_embed_map"

export default class extends Controller {
  static values = {
    center: Array,
    tileUrl: String,
    tileAttribution: String,
    zoom: { type: Number, default: 16 }
  }

  connect() {
    createEmbedMap(this.element, {
      center: this.centerValue,
      zoom: this.zoomValue,
      tileUrl: this.tileUrlValue,
      attribution: this.tileAttributionValue
    })
  }
}
