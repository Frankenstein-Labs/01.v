<script>
import EscalationStatus from '~/sidebar/components/incidents/escalation_status.vue';
import glLicensedFeaturesMixin from '~/vue_shared/mixins/gl_licensed_features_mixin';
import { glListenersMixin } from '~/lib/utils/vue3compat/gl_listeners_mixin';
import { i18nStatusHeaderText, STATUS_SUBTEXTS } from '../../constants';

export default {
  name: 'EscalationStatusEE',
  i18n: i18nStatusHeaderText,

  components: {
    EscalationStatus,
  },
  mixins: [glLicensedFeaturesMixin(), glListenersMixin],
  props: {
    // eslint-disable-next-line @gitlab/vue-require-required-key
    value: EscalationStatus.props.value,
  },
  computed: {
    headerText() {
      return this.escalationPoliciesEnabled ? this.$options.i18n : '';
    },
    statusSubtexts() {
      return this.escalationPoliciesEnabled ? STATUS_SUBTEXTS : {};
    },

    escalationPoliciesEnabled() {
      return this.glLicensedFeatures.escalationPolicies;
    },
  },
  methods: {
    // eslint-disable-next-line vue/no-unused-properties -- show() is part of the component's public API
    show() {
      this.$refs.escalationStatus.show();
    },
    // eslint-disable-next-line vue/no-unused-properties -- hide() is part of the component's public API
    hide() {
      this.$refs.escalationStatus.hide();
    },
  },
};
</script>

<template>
  <escalation-status
    ref="escalationStatus"
    :header-text="headerText"
    :status-subtexts="statusSubtexts"
    :value="value"
    v-bind="$attrs"
    v-on="glListeners()"
  />
</template>
