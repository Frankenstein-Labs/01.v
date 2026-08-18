import Vue from 'vue';
import createStore from 'ee/vue_shared/dashboards/store';
import EnvironmentDashboardComponent from './components/dashboard/dashboard.vue';

export function initEnvironmentsDashboard() {
  const el = document.querySelector('#js-environments');

  if (!el) {
    return null;
  }

  return new Vue({
    el,
    name: 'EnvironmentDashboardComponentRoot',
    store: createStore(),
    components: {
      EnvironmentDashboardComponent,
    },
    render(createElement) {
      return createElement(EnvironmentDashboardComponent, {
        props: this.$el.dataset,
      });
    },
  });
}
