<script>
import {
  GlFormGroup,
  GlFormInput,
  GlCollapsibleListbox,
  GlCard,
  GlButton,
  GlIcon,
  GlSprintf,
  GlTooltipDirective as GlTooltip,
} from '@gitlab/ui';
import { s__ } from '~/locale';
import { ACTIONS, ALERT_STATUSES, EMAIL_ONCALL_SCHEDULE_USER, EMAIL_USER } from '../constants';
import UserSelect from './user_select.vue';

const mapListBoxItems = (source) =>
  Object.entries(source).map(([value, text]) => ({ value, text }));

export const i18n = {
  fields: {
    rules: {
      condition: s__('EscalationPolicies|IF alert is not %{alertStatus} in %{minutes} minutes'),
      action: s__('EscalationPolicies|THEN %{doAction} %{scheduleOrUser}'),
      selectSchedule: s__('EscalationPolicies|Select schedule'),
      noSchedules: s__(
        'EscalationPolicies|A schedule is required for adding an escalation policy. Please create an on-call schedule first.',
      ),
      removeRuleLabel: s__('EscalationPolicies|Remove escalation rule'),
      emptyScheduleValidationMsg: s__(
        'EscalationPolicies|A schedule is required for adding an escalation policy.',
      ),
      invalidTimeValidationMsg: s__('EscalationPolicies|Minutes must be between 0 and 1440.'),
      invalidUserValidationMsg: s__(
        'EscalationPolicies|A user is required for adding an escalation policy.',
      ),
    },
  },
};

export default {
  name: 'EscalationRule',
  i18n,
  ALERT_STATUSES,
  ACTIONS,
  EMAIL_ONCALL_SCHEDULE_USER,
  EMAIL_USER,
  components: {
    GlFormGroup,
    GlFormInput,
    GlCollapsibleListbox,
    GlCard,
    GlButton,
    GlIcon,
    GlSprintf,
    UserSelect,
  },
  directives: {
    GlTooltip,
  },
  props: {
    rule: {
      type: Object,
      required: true,
    },
    schedules: {
      type: Array,
      required: false,
      default: () => [],
    },
    schedulesLoading: {
      type: Boolean,
      required: true,
      default: true,
    },
    mappedParticipants: {
      type: Array,
      required: true,
    },
    index: {
      type: Number,
      required: true,
    },
    validationState: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  emits: ['remove-escalation-rule', 'update-escalation-rule'],
  data() {
    const { status, elapsedTimeMinutes, oncallScheduleIid, username, action } = this.rule;

    return {
      status,
      action,
      elapsedTimeMinutes,
      oncallScheduleIid,
      username,
      hasFocus: true,
    };
  },
  computed: {
    actionsListBoxItems() {
      return mapListBoxItems(ACTIONS);
    },
    alertStatusesListBoxItems() {
      return mapListBoxItems(ALERT_STATUSES);
    },
    schedulesListBoxItems() {
      return this.schedules?.map(({ iid, name, id }) => ({ value: iid || id, text: name }));
    },
    scheduleDropdownTitle() {
      return this.oncallScheduleIid
        ? this.schedules.find(({ iid }) => iid === this.oncallScheduleIid)?.name
        : i18n.fields.rules.selectSchedule;
    },
    noSchedules() {
      return !this.schedulesLoading && !this.schedules.length;
    },
    isValid() {
      return this.isTimeValid && this.isScheduleValid && this.isUserValid;
    },
    isTimeValid() {
      return this.validationState?.isTimeValid;
    },
    isScheduleValid() {
      return this.validationState?.isScheduleValid;
    },
    isUserValid() {
      return this.validationState?.isUserValid;
    },
    isEmailOncallScheduleUserActionSelected() {
      return this.action === EMAIL_ONCALL_SCHEDULE_USER;
    },
    isEmailUserActionSelected() {
      return this.action === EMAIL_USER;
    },
    actionBasedRequestParams() {
      if (this.isEmailOncallScheduleUserActionSelected) {
        return { oncallScheduleIid: parseInt(this.oncallScheduleIid, 10) };
      }

      return { username: this.username };
    },
  },
  mounted() {
    this.ruleContainer = this.$refs.ruleContainer?.$el;
    this.ruleContainer?.addEventListener('focusin', this.addFocus);
    this.ruleContainer?.addEventListener('focusout', this.removeFocus);
  },
  beforeDestroy() {
    this.ruleContainer?.removeEventListener('focusin', this.addFocus);
    this.ruleContainer?.removeEventListener('focusout', this.removeFocus);
  },
  methods: {
    addFocus() {
      this.hasFocus = true;
    },
    removeFocus() {
      this.hasFocus = false;
    },
    setOncallSchedule(iid) {
      this.oncallScheduleIid = iid;
      this.emitUpdate();
    },
    setAction(action) {
      this.action = action;
      if (this.isEmailOncallScheduleUserActionSelected) {
        this.username = null;
      } else if (this.isEmailUserActionSelected) {
        this.oncallScheduleIid = null;
      }
      this.emitUpdate();
    },
    setStatus(status) {
      this.status = status;
      this.emitUpdate();
    },
    setSelectedUser(username) {
      this.username = username;
      this.emitUpdate();
    },
    emitUpdate() {
      this.$emit('update-escalation-rule', {
        index: this.index,
        rule: {
          ...this.actionBasedRequestParams,
          action: this.action,
          status: this.status,
          elapsedTimeMinutes: this.elapsedTimeMinutes,
        },
      });
    },
  },
};
</script>

<template>
  <gl-card ref="ruleContainer" class="gl-relative gl-mb-3 gl-border-0">
    <gl-button
      v-if="index !== 0"
      category="tertiary"
      size="small"
      icon="close"
      :aria-label="$options.i18n.fields.rules.removeRuleLabel"
      class="rule-close-icon gl-absolute"
      @click="$emit('remove-escalation-rule', index)"
    />
    <gl-form-group :state="isValid" class="gl-mb-0">
      <template #invalid-feedback>
        <div v-if="!isScheduleValid && !hasFocus">
          {{ $options.i18n.fields.rules.emptyScheduleValidationMsg }}
        </div>
        <div v-if="!isUserValid && !hasFocus" class="gl-mt-2 gl-inline-block">
          {{ $options.i18n.fields.rules.invalidUserValidationMsg }}
        </div>
        <div v-if="!isTimeValid && !hasFocus" class="gl-mt-2 gl-inline-block">
          {{ $options.i18n.fields.rules.invalidTimeValidationMsg }}
        </div>
      </template>

      <div class="gl-flex gl-items-center">
        <gl-sprintf :message="$options.i18n.fields.rules.condition">
          <template #alertStatus>
            <gl-collapsible-listbox
              data-testid="alert-status-dropdown"
              toggle-class="gl-mx-3"
              :items="alertStatusesListBoxItems"
              :selected="status"
              :toggle-text="$options.ALERT_STATUSES[status]"
              @select="setStatus"
            />
          </template>
          <template #minutes>
            <gl-form-input
              v-model="elapsedTimeMinutes"
              class="gl-mx-3 gl-w-12 !gl-shadow-inner-1-gray-200"
              number
              min="0"
              @input="emitUpdate"
            />
          </template>
        </gl-sprintf>
      </div>
      <div class="gl-mt-3 gl-flex gl-items-center">
        <gl-sprintf :message="$options.i18n.fields.rules.action">
          <template #doAction>
            <gl-collapsible-listbox
              toggle-class="gl-mx-3"
              data-testid="action-dropdown"
              :selected="action"
              :toggle-text="$options.ACTIONS[action]"
              :items="actionsListBoxItems"
              @select="setAction"
            />
          </template>
          <template #scheduleOrUser>
            <template v-if="isEmailOncallScheduleUserActionSelected">
              <gl-collapsible-listbox
                data-testid="schedules-dropdown"
                :disabled="noSchedules"
                :items="schedulesListBoxItems"
                :selected="oncallScheduleIid"
                :toggle-text="scheduleDropdownTitle"
                @select="setOncallSchedule"
              />
              <gl-icon
                v-if="noSchedules"
                v-gl-tooltip
                :title="$options.i18n.fields.rules.noSchedules"
                name="information-o"
                class="gl-ml-3"
                data-testid="no-schedules-info-icon"
                variant="subtle"
              />
            </template>
            <user-select
              v-else
              :selected-user-name="username"
              :mapped-participants="mappedParticipants"
              @select-user="setSelectedUser"
            />
          </template>
        </gl-sprintf>
      </div>
    </gl-form-group>
  </gl-card>
</template>
