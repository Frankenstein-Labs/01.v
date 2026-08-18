/// <reference types="vite/client" />

import { defineCustomElement } from 'vue';
import CommunicationLayer from './CommunicationLayer.vue';
import tailwind from './style.css?inline';

const DuoNextElement = defineCustomElement(CommunicationLayer, {
  styles: [tailwind],
});

customElements.define('fe-island-duo-next', DuoNextElement);
