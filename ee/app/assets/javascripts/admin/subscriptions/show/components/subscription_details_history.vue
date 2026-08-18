<script>
import { GlBadge, GlTableLite } from '@gitlab/ui';
import { kebabCase } from 'lodash-es';
import { detailsLabels, subscriptionTable } from '../constants';
import { formatPlan, getLicenseTypeLabel } from '../utils';

const tdAttr = (_, key) => ({ 'data-testid': `subscription-cell-${kebabCase(key)}` });
// eslint-disable-next-line max-params
const thAttr = (_, key, _item, type) => {
  if (type !== 'head') {
    return tdAttr(_, key);
  }
  return {};
};
const tdClassHighlight = '!gl-bg-blue-50';

export default {
  i18n: {
    subscriptionHistoryTitle: subscriptionTable.title,
    detailsLabels,
  },
  name: 'SubscriptionDetailsHistory',
  components: {
    GlBadge,
    GlTableLite,
  },
  props: {
    currentSubscriptionId: {
      type: String,
      required: false,
      default: null,
    },
    subscriptionList: {
      type: Array,
      required: true,
    },
  },
  data() {
    return {
      fields: [
        {
          key: 'name',
          label: detailsLabels.name,
          thAttr,
          isRowHeader: true,
          tdClass: this.cellClass,
        },
        {
          key: 'plan',
          formatter: (v, k, item) => formatPlan(item.plan, item),
          label: detailsLabels.plan,
          tdAttr,
          tdClass: this.cellClass,
        },
        {
          key: 'activatedAt',
          formatter: (v, k, { activatedAt }) => {
            if (!activatedAt) {
              return '-';
            }

            return activatedAt;
          },
          label: subscriptionTable.activatedAt,
          tdAttr,
          tdClass: this.cellClass,
        },
        {
          key: 'startsAt',
          label: subscriptionTable.startsAt,
          tdAttr,
          tdClass: this.cellClass,
        },
        {
          key: 'expiresAt',
          label: subscriptionTable.expiresOn,
          tdAttr,
          tdClass: this.cellClass,
        },
        {
          key: 'usersInLicenseCount',
          label: subscriptionTable.seats,
          tdAttr,
          tdClass: this.cellClass,
        },
        {
          key: 'type',
          formatter: (v, k, item) => getLicenseTypeLabel(item.type),
          label: subscriptionTable.type,
          tdAttr,
          tdClass: this.cellClass,
        },
      ],
    };
  },
  methods: {
    cellClass(_, x, item) {
      return this.isCurrentSubscription(item) ? tdClassHighlight : '';
    },
    isCurrentSubscription({ id }) {
      return id === this.currentSubscriptionId;
    },
    rowAttr() {
      return {
        'data-testid': 'subscription-history-row',
      };
    },
  },
};
</script>

<template>
  <section>
    <header>
      <h2 class="gl-mb-6 gl-mt-0">
        {{ $options.i18n.subscriptionHistoryTitle }}
      </h2>
    </header>
    <gl-table-lite
      :details-td-class="$options.tdClass"
      :fields="fields"
      :items="subscriptionList"
      :tbody-tr-attr="rowAttr"
      responsive
      stacked="sm"
      data-testid="subscription-history"
    >
      <template #cell(name)="{ item }">
        <span class="gl-break-words gl-font-normal">
          <span>{{ item.name }}</span>
          <span class="gl-block gl-text-sm gl-text-subtle">
            {{ item.email }} ({{ item.company }})
          </span>
        </span>
      </template>
      <template #cell(type)="{ value }">
        <gl-badge variant="info">{{ value }}</gl-badge>
      </template>
    </gl-table-lite>
  </section>
</template>
