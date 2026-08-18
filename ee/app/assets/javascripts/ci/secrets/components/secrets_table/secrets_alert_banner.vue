<script>
import { GlAlert, GlAccordion, GlAccordionItem } from '@gitlab/ui';
import { n__ } from '~/locale';
import { DETAILS_ROUTE_NAME, SECRET_ROTATION_STATUS } from '../../constants';

export default {
  name: 'SecretsAlertBanner',
  components: {
    GlAlert,
    GlAccordion,
    GlAccordionItem,
  },
  props: {
    secretsToRotate: {
      type: Array,
      required: true,
    },
  },
  computed: {
    overdueForRotation() {
      return this.secretsToRotate.filter(
        (secret) => secret.rotationInfo?.status === SECRET_ROTATION_STATUS.overdue,
      );
    },
    approachingRotation() {
      return this.secretsToRotate.filter(
        (secret) => secret.rotationInfo?.status === SECRET_ROTATION_STATUS.approaching,
      );
    },
    approachingRotationText() {
      return n__(
        'SecretRotation|%d secret needs to be manually rotated soon to maintain security',
        'SecretRotation|%d secrets need to be manually rotated soon to maintain security',
        this.approachingRotation.length,
      );
    },
    overdueForRotationText() {
      return n__(
        'SecretRotation|%d secret has not been rotated after the configured rotation reminder intervals',
        'SecretRotation|%d secrets have not been rotated after the configured rotation reminder intervals',
        this.overdueForRotation.length,
      );
    },
  },
  methods: {
    getDetailsRoute(secretName) {
      return {
        name: DETAILS_ROUTE_NAME,
        params: { secretName },
      };
    },
  },
};
</script>
<template>
  <gl-alert
    class="gl-m-5 gl-pb-0"
    :title="s__('SecretRotation|Some secrets require your attention')"
    dismissible
    :dismiss-label="__('Dismiss')"
    variant="warning"
  >
    <ul class="gl-pl-5">
      <li v-if="approachingRotation.length">
        {{ approachingRotationText }}
        <gl-accordion :header-level="1">
          <gl-accordion-item :title="__('Show details')" :header-level="1">
            <ul class="gl-m-0 gl-pl-5">
              <li v-for="secret in approachingRotation" :key="secret.id">
                <router-link :to="getDetailsRoute(secret.name)" class="gl-block">
                  {{ secret.name }}
                </router-link>
              </li>
            </ul>
          </gl-accordion-item>
        </gl-accordion>
      </li>
      <li v-if="overdueForRotation.length">
        {{ overdueForRotationText }}
        <gl-accordion :header-level="1">
          <gl-accordion-item :title="__('Show details')" :header-level="1">
            <ul class="gl-m-0 gl-pl-5">
              <li v-for="secret in overdueForRotation" :key="secret.id">
                <router-link :to="getDetailsRoute(secret.name)" class="gl-block">
                  {{ secret.name }}
                </router-link>
              </li>
            </ul>
          </gl-accordion-item>
        </gl-accordion>
      </li>
    </ul>
  </gl-alert>
</template>
