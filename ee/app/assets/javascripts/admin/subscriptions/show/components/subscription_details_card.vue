<script>
import { GlCard } from '@gitlab/ui';
import { identity } from 'lodash-es';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { getTimeago, timeagoLanguageCode } from '~/lib/utils/datetime_utility';
import SubscriptionDetailsTable from 'jh_else_ee/admin/subscriptions/show/components/subscription_details_table.vue';
import { glSlotsMixin } from '~/lib/utils/vue3compat/gl_slots_mixin';
import { formatPlan } from '../utils';

const timeagoFormatter = getTimeago().format;
const formatTime = (time) => timeagoFormatter(time, timeagoLanguageCode);

const subscriptionDetailsFormatRules = {
  id: getIdFromGraphQLId,
  lastSync: formatTime,
  plan: formatPlan,
};

export default {
  name: 'SubscriptionDetailsCard',
  components: {
    GlCard,
    SubscriptionDetailsTable,
  },
  mixins: [glSlotsMixin],
  props: {
    detailsFields: {
      type: Array,
      required: true,
    },
    headerText: {
      type: String,
      required: false,
      default: '',
    },
    subscription: {
      type: Object,
      required: true,
    },
  },
  computed: {
    details() {
      return this.detailsFields.map((detail) => {
        const formatter = subscriptionDetailsFormatRules[detail] || identity;
        const valueToFormat = this.subscription[detail];
        const value = valueToFormat ? formatter(valueToFormat, this.subscription) : '';
        return { detail, value };
      });
    },
    hasFooterContent() {
      return Boolean(this.glSlots().footer);
    },
  },
};
</script>

<template>
  <gl-card>
    <template v-if="headerText" #header>
      <h6 class="gl-m-0">{{ headerText }}</h6>
    </template>
    <subscription-details-table :details="details" :subscription-type="subscription.type" />
    <template v-if="hasFooterContent" #footer>
      <slot name="footer"></slot>
    </template>
  </gl-card>
</template>
