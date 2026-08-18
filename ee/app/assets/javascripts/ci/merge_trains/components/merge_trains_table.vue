<script>
import { GlButton, GlKeysetPagination, GlLink, GlTable, GlModalDirective } from '@gitlab/ui';
import CiIcon from '~/vue_shared/components/ci_icon/ci_icon.vue';
import UserAvatarLink from '~/vue_shared/components/user_avatar/user_avatar_link.vue';
import { getTimeago } from '~/lib/utils/datetime_utility';
import { __, sprintf } from '~/locale';
import { CARS_PER_PAGE, MODAL_ID } from '../constants';
import DeleteCarModalConfirmation from './delete_car_modal_confirmation.vue';

export default {
  name: 'MergeTrainsTable',
  MODAL_ID,
  fields: [
    {
      key: 'mr',
      label: __('Merge request'),
      thClass: '!gl-border-t-0',
      columnClass: 'gl-w-9/10',
    },
    {
      key: 'actions',
      label: '',
      thClass: '!gl-border-t-0',
      tdClass: 'gl-text-right',
      columnClass: 'gl-w-1/10',
    },
  ],
  components: {
    CiIcon,
    GlButton,
    GlKeysetPagination,
    GlLink,
    GlTable,
    DeleteCarModalConfirmation,
    UserAvatarLink,
  },
  directives: {
    GlModal: GlModalDirective,
  },
  props: {
    train: {
      type: Object,
      required: true,
    },
    // used in conjunction with userPermissions to ensure
    // the remove car button is only showed for active cars
    isActiveTab: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['delete-car', 'page-change'],
  data() {
    return {
      carToRemoveId: null,
      mergeRequestTitle: '',
    };
  },
  computed: {
    cars() {
      return this.train?.cars?.nodes || [];
    },
    pageInfo() {
      return this.train?.cars?.pageInfo || {};
    },
    showPagination() {
      return this.pageInfo?.hasPreviousPage || this.pageInfo?.hasNextPage;
    },
  },
  methods: {
    buildTimeAgoString({ createdAt, mergedAt }) {
      let timeAgo;

      if (mergedAt) {
        timeAgo = getTimeago().format(mergedAt);

        return sprintf(__('Merged %{timeAgo} by'), { timeAgo });
      }

      timeAgo = getTimeago().format(createdAt);

      return sprintf(__('Added %{timeAgo} by'), { timeAgo });
    },
    nextPage(item) {
      this.$emit('page-change', {
        first: CARS_PER_PAGE,
        after: item,
        last: null,
        before: null,
      });
    },
    prevPage(item) {
      this.$emit('page-change', {
        first: null,
        after: null,
        last: CARS_PER_PAGE,
        before: item,
      });
    },
    setData(data) {
      this.carToRemoveId = data.id;
      this.mergeRequestTitle = data?.mergeRequest?.title || '';
    },
  },
};
</script>

<template>
  <div>
    <gl-table :items="cars" :fields="$options.fields" stacked="md">
      <template #table-colgroup="{ fields }">
        <col v-for="field in fields" :key="field.key" :class="field.columnClass" />
      </template>

      <template #cell(mr)="{ item }">
        <ci-icon v-if="item.pipeline" :status="item.pipeline.detailedStatus" />
        <gl-link :href="item.mergeRequest.webPath" class="gl-ml-3 gl-underline">{{
          item.mergeRequest.title
        }}</gl-link>
        <div class="gl-ml-3 gl-inline-block">
          <span data-testid="timeago-train-text">
            {{ buildTimeAgoString(item) }}
          </span>
          <user-avatar-link
            :link-href="item.user.webPath"
            :img-src="item.user.avatarUrl"
            :img-size="16"
            :img-alt="item.user.name"
            :tooltip-text="item.user.name"
            class="gl-ml-1"
          />
        </div>
      </template>
      <template #cell(actions)="{ item }">
        <gl-button
          v-if="item.userPermissions.deleteMergeTrainCar && isActiveTab"
          v-gl-modal="$options.MODAL_ID"
          icon="close"
          :aria-label="__('Close')"
          data-testid="remove-car-button"
          @click="setData(item)"
        />
      </template>
    </gl-table>
    <div class="gl-mt-5 gl-flex gl-justify-center">
      <gl-keyset-pagination
        v-if="showPagination"
        v-bind="pageInfo"
        @prev="prevPage"
        @next="nextPage"
      />
    </div>

    <delete-car-modal-confirmation
      :merge-request-title="mergeRequestTitle"
      @remove-car-confirmed="$emit('delete-car', carToRemoveId)"
    />
  </div>
</template>
