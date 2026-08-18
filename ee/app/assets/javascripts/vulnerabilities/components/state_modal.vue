<script>
import { GlModal, GlForm, GlFormGroup, GlCollapsibleListbox, GlFormInput } from '@gitlab/ui';
import { __, s__, sprintf } from '~/locale';
import { VULNERABILITY_STATE_OBJECTS, DISMISSAL_REASONS } from '../constants';

const { dismissed, ...VULNERABILITY_STATE_OBJECTS_WITHOUT_DISMISSED } = VULNERABILITY_STATE_OBJECTS;
const STATES = Object.keys(VULNERABILITY_STATE_OBJECTS_WITHOUT_DISMISSED).map((state) => ({
  value: state,
  text: VULNERABILITY_STATE_OBJECTS[state].dropdownText,
  dropdownDescription: VULNERABILITY_STATE_OBJECTS[state].dropdownDescription,
}));
const STATES_GROUP = { text: s__('VulnerabilityStatusTypes|Mark as...'), options: STATES };

export default {
  name: 'StateModal',
  components: {
    GlModal,
    GlForm,
    GlFormGroup,
    GlCollapsibleListbox,
    GlFormInput,
  },
  inject: ['dismissalDescriptions'],
  props: {
    modalId: { type: String, required: true },
    state: { type: String, required: true },
    dismissalReason: { type: String, required: false, default: null },
    comment: { type: String, required: false, default: null },
  },
  emits: ['change'],
  data() {
    return {
      form: {
        status: {
          value: this.state,
          state: null,
        },
        dismissalReason: {
          value: this.dismissalReason,
        },
        comment: {
          value: this.comment,
          state: null,
        },
      },
    };
  },
  computed: {
    isDismissedState() {
      return (
        this.form.dismissalReason.value ||
        this.form.status.value === VULNERABILITY_STATE_OBJECTS.dismissed.state
      );
    },
    stateItem() {
      return VULNERABILITY_STATE_OBJECTS[this.form.status.value];
    },
    statusToggleText() {
      if (this.form.dismissalReason.value) {
        return sprintf(s__('VulnerabilityManagement|Dismissed: %{dismissalReason}'), {
          dismissalReason: DISMISSAL_REASONS[this.form.dismissalReason.value],
        });
      }
      return this.stateItem?.buttonText;
    },
    dismissalReasonGroup() {
      return {
        text: s__('VulnerabilityManagement|Dismiss as...'),
        options: Object.entries(DISMISSAL_REASONS).map(([value, text]) => ({
          value,
          text,
          dropdownDescription: this.dismissalDescriptions?.[value],
          isDismissalReason: true,
        })),
      };
    },
    statusItems() {
      return [STATES_GROUP, this.dismissalReasonGroup];
    },
    selectedStatus() {
      return this.isDismissedState ? this.form.dismissalReason.value : this.form.status.value;
    },
    commentLabel() {
      return this.isDismissedState
        ? this.$options.i18n.commentRequired
        : this.$options.i18n.comment;
    },
  },
  methods: {
    init() {
      this.form = {
        status: { value: this.state, state: null },
        dismissalReason: { value: this.dismissalReason },
        comment: { value: this.comment, state: null },
      };
    },
    updateStatus(selected) {
      if (Object.keys(DISMISSAL_REASONS).includes(selected)) {
        this.form.dismissalReason = { value: selected };
        this.form.status = {
          value: VULNERABILITY_STATE_OBJECTS.dismissed.state,
          state: null,
        };
      } else {
        this.form.status = {
          value: selected,
          state: null,
        };
        this.form.dismissalReason = { value: null };
      }
    },
    validate() {
      if (this.isDismissedState) {
        this.form.status.state = true;
        this.form.comment.state = Boolean(this.form.comment.value);
      } else {
        this.form.status.state = this.state !== this.form.status.value;
      }
    },
    submit(event) {
      this.validate();

      if (this.form.comment.state === false || this.form.status.state === false) {
        event.preventDefault();
        return;
      }

      this.$emit('change', {
        action: this.stateItem.action,
        dismissalReason: this.form.dismissalReason.value?.toUpperCase(),
        comment: this.form.comment.value,
      });
    },
  },
  actionPrimary: {
    text: s__('SecurityReports|Change status'),
    attributes: {
      variant: 'confirm',
      'data-testid': 'change-status-modal-btn',
    },
  },
  actionCancel: {
    text: __('Cancel'),
  },
  i18n: {
    changeStatus: s__('SecurityReports|Change status'),
    status: s__('SecurityReports|Status'),
    comment: __('Comment'),
    commentRequired: s__('SecurityReports|Comment (required)'),
    requiredComment: s__('SecurityReports|A comment is required when dismissing.'),
    differentStatusRequired: s__(
      'SecurityReports|New status must be different than current status.',
    ),
  },
};
</script>

<template>
  <gl-modal
    size="sm"
    :modal-id="modalId"
    :title="$options.i18n.changeStatus"
    :action-primary="$options.actionPrimary"
    :action-cancel="$options.actionCancel"
    @primary="submit"
    @show="init"
  >
    <gl-form @submit="submit">
      <gl-form-group
        label-for="vulnerability-status"
        :label="$options.i18n.status"
        :state="form.status.state"
        :invalid-feedback="$options.i18n.differentStatusRequired"
        data-testid="vulnerability-status-form-group"
      >
        <gl-collapsible-listbox
          id="vulnerability-status"
          :selected="selectedStatus"
          :items="statusItems"
          :toggle-text="statusToggleText"
          fluid-width
          data-testid="vulnerability-status-listbox"
          @select="updateStatus"
        >
          <template #list-item="{ item }">
            <span class="gl-flex gl-flex-col">
              <span class="gl-whitespace-nowrap gl-font-bold">{{ item.text }}</span>
              <span class="gl-text-subtle" :class="{ 'gl-text-sm': item.isDismissalReason }">
                {{ item.dropdownDescription }}</span
              >
            </span>
          </template>
        </gl-collapsible-listbox>
      </gl-form-group>
      <gl-form-group
        label-for="vulnerability-comment"
        :label="commentLabel"
        :state="form.comment.state"
        :invalid-feedback="$options.i18n.requiredComment"
        data-testid="vulnerability-comment-form-group"
      >
        <gl-form-input
          id="vulnerability-comment"
          v-model="form.comment.value"
          data-testid="vulnerability-comment-input"
          @input="form.comment.state = true"
        />
      </gl-form-group>
    </gl-form>
  </gl-modal>
</template>
