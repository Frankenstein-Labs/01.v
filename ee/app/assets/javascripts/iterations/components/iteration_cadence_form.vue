<script>
import {
  GlAlert,
  GlButton,
  GlDatepicker,
  GlForm,
  GlFormCheckbox,
  GlFormGroup,
  GlFormInput,
  GlFormSelect,
  GlFormTextarea,
  GlSprintf,
} from '@gitlab/ui';
import { TYPENAME_ITERATIONS_CADENCE } from '~/graphql_shared/constants';
import { convertToGraphQLId, getIdFromGraphQLId } from '~/graphql_shared/utils';
import { STATUS_ALL } from '~/issues/constants';
import { s__, n__, __, sprintf } from '~/locale';
import { getDayName, formatTimezone } from '~/lib/utils/datetime_utility';
import createCadence from '../queries/cadence_create.mutation.graphql';
import updateCadence from '../queries/cadence_update.mutation.graphql';
import readCadence from '../queries/iteration_cadence.query.graphql';
import iterationsInCadence from '../queries/group_iterations_in_cadence.query.graphql';

const i18n = Object.freeze({
  automatedScheduling: {
    heading: s__('Iterations|Automatic scheduling'),
    text: s__('Iterations|Create iterations automatically on a regular schedule.'),
    label: s__('Iterations|Enable automatic scheduling'),
  },
  title: {
    label: s__('Iterations|Title'),
    placeholder: s__('Iterations|Cadence name'),
  },
  automationStartDate: {
    label: s__('Iterations|Automation start date'),
    placeholder: s__('Iterations|Select start date'),
    labelDescription: s__(
      'Iterations|The date of the first iteration to schedule. This date determines the day of the week when each iteration starts.',
    ),
    description: s__('Iterations|Iterations are scheduled to start on %{weekday}s.'),
  },
  duration: {
    label: s__('Iterations|Duration'),
    labelDescription: s__('Iterations|The duration of each iteration.'),
  },
  rollOver: {
    label: s__('Iterations|Roll over issues'),
    checkboxLabel: s__('Iterations|Enable roll over'),
    description: s__(
      'Iterations|Incomplete issues will be added to the next iteration at %{strongStart}midnight, %{timezone}%{strongEnd}.',
    ),
  },
  upcomingIterations: {
    label: s__('Iterations|Upcoming iterations'),
    labelDescription: s__(
      'Iterations|Number of future iterations to schedule in addition to the current one.',
    ),
    description: s__(
      'Iterations|All scheduled iterations will remain scheduled even if you use a smaller number.',
    ),
  },
  description: {
    label: __('Description'),
    optional: __('(optional)'),
  },
  edit: {
    title: s__('Iterations|Edit iteration cadence'),
    save: s__('Iterations|Save changes'),
  },
  new: {
    title: s__('Iterations|New iteration cadence'),
    save: s__('Iterations|Create cadence'),
  },
  cancel: __('Cancel'),
  requiredField: __('This field is required.'),
});

export default {
  name: 'IterationCadenceForm',
  availableDurations: [1, 2, 3, 4].map((i) => ({
    value: i,
    text: n__('Iterations|%d week', 'Iterations|%d weeks', i),
  })),
  availableUpcomingIterations: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10].map((i) => ({
    value: i,
    text: n__('Iterations|%d iteration', 'Iterations|%d iterations', i),
  })),

  components: {
    GlAlert,
    GlButton,
    GlDatepicker,
    GlForm,
    GlFormCheckbox,
    GlFormGroup,
    GlFormInput,
    GlFormSelect,
    GlFormTextarea,
    GlSprintf,
  },
  inject: ['fullPath', 'cadencesListPath', 'instanceTimezone'],
  data() {
    return {
      group: {
        loading: false,
        iterationCadences: {
          nodes: [],
        },
      },
      iterations: [],
      loading: false,
      errorMessage: '',
      title: '',
      automatic: true,
      rollOver: true,
      startDate: null,
      durationInWeeks: 2,
      iterationsInAdvance: 4,
      description: '',
      validationState: {
        title: null,
        startDate: null,
        durationInWeeks: null,
        iterationsInAdvance: null,
      },
      i18n,
    };
  },
  computed: {
    automationStartDateDescription() {
      if (this.startDate === null) return '';

      return sprintf(this.i18n.automationStartDate.description, {
        weekday: getDayName(new Date(this.startDate)),
      });
    },
    formattedTimezoneMessage() {
      return sprintf(this.i18n.rollOver.description, {
        timezone: formatTimezone(this.instanceTimezone),
      });
    },
    loadingCadence() {
      return this.$apollo.queries.group.loading;
    },
    disableAutomationFields() {
      return this.loadingCadence || !this.automatic;
    },
    cadenceId() {
      return this.$router.currentRoute.params.cadenceId;
    },
    isEdit() {
      return Boolean(this.cadenceId);
    },
    page() {
      return this.isEdit ? 'edit' : 'new';
    },
    mutation() {
      return this.isEdit ? updateCadence : createCadence;
    },
    valid() {
      return !Object.values(this.validationState).includes(false);
    },
    variables() {
      const id = this.isEdit
        ? convertToGraphQLId(TYPENAME_ITERATIONS_CADENCE, this.cadenceId)
        : undefined;
      const groupPath = this.isEdit ? undefined : this.fullPath;

      const vars = {
        input: {
          groupPath,
          id,
          title: this.title,
          automatic: this.automatic,
          rollOver: this.rollOver,
          startDate: this.startDate,
          durationInWeeks: this.durationInWeeks,
          active: true,
          iterationsInAdvance: this.iterationsInAdvance,
          description: this.description,
        },
      };

      return vars;
    },
  },
  mounted() {
    this.$apollo.queries.iterations.refetch();
  },
  apollo: {
    group: {
      skip() {
        return !this.isEdit;
      },
      query: readCadence,
      variables() {
        return {
          fullPath: this.fullPath,
          id: convertToGraphQLId(TYPENAME_ITERATIONS_CADENCE, this.cadenceId),
        };
      },
      result({ data: { group, errors }, error }) {
        if (error) {
          return;
        }

        if (errors?.length) {
          [this.errorMessage] = errors;
          return;
        }
        const cadence = group?.iterationCadences?.nodes?.[0];

        if (!cadence) {
          this.errorMessage = s__("Iterations|Couldn't find iteration cadence");
          return;
        }

        this.title = cadence.title;
        this.description = cadence.description;
        this.automatic = cadence.automatic;

        if (this.automatic) {
          this.startDate = cadence.startDate;
          this.durationInWeeks = cadence.durationInWeeks;
          this.rollOver = cadence.rollOver;
          this.iterationsInAdvance = cadence.iterationsInAdvance;

          this.validateAllFields();
        } else {
          this.clearAutomaticFields();
        }
      },
      error(error) {
        this.errorMessage = error;
      },
    },
    iterations: {
      query: iterationsInCadence,
      skip() {
        return !this.isEdit || this.loadingCadence;
      },
      variables() {
        return {
          fullPath: this.fullPath,
          iterationCadenceId: convertToGraphQLId(TYPENAME_ITERATIONS_CADENCE, this.cadenceId),
          firstPageSize: 1,
          state: STATUS_ALL,
        };
      },
      update({ namespace } = {}) {
        if (!namespace) return [];

        return namespace.iterations?.nodes || [];
      },
      error(error) {
        this.errorMessage = error;
      },
    },
  },
  methods: {
    validate(field) {
      this.validationState[field] =
        this[field] !== null && this[field] !== undefined && this[field] !== '';
    },
    validateAllFields() {
      this.validate('title');

      if (this.automatic) {
        Object.keys(this.validationState).forEach((field) => {
          this.validate(field);
        });
      }
    },
    clearValidation() {
      this.validationState.startDate = null;
      this.validationState.durationInWeeks = null;
      this.validationState.iterationsInAdvance = null;
    },
    clearAutomaticFields() {
      this.startDate = null;
      this.durationInWeeks = null;
      this.rollOver = false;
      this.iterationsInAdvance = null;
    },
    saveAndViewList() {
      return this.save()
        .then((cadenceId) => {
          this.$router.push({
            name: 'index',
            query: { createdCadenceId: getIdFromGraphQLId(cadenceId) },
          });
        })
        .catch((error) => {
          this.errorMessage =
            error?.message ?? s__('Iterations|Unable to save cadence. Please try again.');
        });
    },
    save() {
      return new Promise((resolve, reject) => {
        this.validateAllFields();

        if (!this.valid) {
          reject(new Error(s__('Iterations|Required fields missing.')));
        }

        resolve();
      })
        .then(() => {
          this.loading = true;
          return this.saveCadence();
        })
        .finally(() => {
          this.loading = false;
        });
    },
    cancel() {
      this.$router.push({ name: 'index' });
    },
    saveCadence() {
      return this.$apollo
        .mutate({
          mutation: this.mutation,
          variables: this.variables,
        })
        .then(({ data } = {}) => {
          const { iterationCadence, errors } = data?.result || {};

          if (errors?.length > 0) {
            throw new Error(errors);
          }

          return getIdFromGraphQLId(iterationCadence.id);
        });
    },
    updateAutomatic(value) {
      if (value) return;

      this.clearValidation();
      this.clearAutomaticFields();
    },
  },
};
</script>

<template>
  <article>
    <div class="gl-flex">
      <h1 ref="pageTitle" class="page-title gl-text-size-h-display">
        {{ i18n[page].title }}
      </h1>
    </div>

    <gl-form>
      <gl-alert v-if="errorMessage" class="gl-mb-5" variant="danger" @dismiss="errorMessage = ''">{{
        errorMessage
      }}</gl-alert>

      <gl-form-group
        class="gl-pt-3"
        :label="i18n.title.label"
        label-for="cadence-title"
        :invalid-feedback="i18n.requiredField"
        :state="validationState.title"
      >
        <gl-form-input
          id="cadence-title"
          v-model="title"
          autocomplete="off"
          data-testid="iteration-cadence-title-field"
          :placeholder="i18n.title.placeholder"
          :state="validationState.title"
          :disabled="loadingCadence"
          @blur="validate('title')"
        />
      </gl-form-group>

      <gl-form-group
        class="gl-pt-3"
        :label="i18n.description.label"
        :optional-text="i18n.optional"
        label-for="cadence-description"
        optional
      >
        <gl-form-textarea
          id="cadence-description"
          v-model="description"
          data-testid="iteration-cadence-description-field"
          no-resize
        />
      </gl-form-group>

      <h4 class="gl-pt-3">{{ i18n.automatedScheduling.heading }}</h4>
      <p>{{ i18n.automatedScheduling.text }}</p>

      <gl-form-checkbox
        id="cadence-automated-scheduling"
        v-model="automatic"
        :disabled="loadingCadence"
        data-testid="automated-scheduling-checkbox"
        @change="updateAutomatic"
      >
        <span>{{ i18n.automatedScheduling.label }}</span>
      </gl-form-checkbox>

      <div class="gl-border gl-mb-6 gl-mt-4 gl-rounded-base gl-px-4 gl-pt-4">
        <gl-form-group
          class="gl-pt-3"
          :label="i18n.automationStartDate.label"
          :label-description="i18n.automationStartDate.labelDescription"
          label-for="cadence-start-date"
          :description="automationStartDateDescription"
          :invalid-feedback="i18n.requiredField"
          :state="validationState.startDate"
        >
          <gl-datepicker
            v-model="startDate"
            input-id="cadence-start-date"
            :placeholder="i18n.automationStartDate.placeholder"
            autocomplete="off"
            inputmode="none"
            :disabled="disableAutomationFields"
            :state="validationState.startDate"
            data-testid="iteration-cadence-start-date-field"
            @blur="validate('startDate')"
            @input="validate('startDate')"
          />
        </gl-form-group>

        <gl-form-group
          class="gl-pt-3"
          :label="i18n.duration.label"
          :label-description="i18n.duration.labelDescription"
          label-for="cadence-duration"
          :invalid-feedback="i18n.requiredField"
          :state="validationState.durationInWeeks"
        >
          <gl-form-select
            id="cadence-duration"
            v-model.number="durationInWeeks"
            :options="$options.availableDurations"
            class="gl-form-input-md"
            :disabled="disableAutomationFields"
            data-testid="iteration-cadence-duration-field"
            @change="validate('durationInWeeks')"
          />
        </gl-form-group>

        <gl-form-group
          class="gl-pt-3"
          :label="i18n.upcomingIterations.label"
          :label-description="i18n.upcomingIterations.labelDescription"
          label-for="cadence-schedule-upcoming-iterations"
          :invalid-feedback="i18n.requiredField"
          :state="validationState.iterationsInAdvance"
          :description="i18n.upcomingIterations.description"
        >
          <gl-form-select
            id="cadence-schedule-upcoming-iterations"
            v-model.number="iterationsInAdvance"
            :disabled="disableAutomationFields"
            :options="$options.availableUpcomingIterations"
            class="gl-form-input-md"
            data-testid="iteration-cadence-upcoming-iterations-field"
            @change="validate('iterationsInAdvance')"
          />
        </gl-form-group>

        <gl-form-group
          class="gl-pt-3"
          :label="i18n.rollOver.label"
          label-class="gl-font-bold"
          label-for="cadence-rollover-issues"
          data-testid="cadence-rollover-group"
        >
          <template #description>
            <gl-sprintf :message="formattedTimezoneMessage">
              <template #strong="{ content }">
                <strong>{{ content }}</strong>
              </template>
            </gl-sprintf>
          </template>
          <gl-form-checkbox
            id="cadence-rollover-issues"
            v-model="rollOver"
            :disabled="disableAutomationFields"
            @change="clearValidation"
          >
            <span>{{ i18n.rollOver.checkboxLabel }}</span>
          </gl-form-checkbox>
        </gl-form-group>
      </div>

      <div class="gl-flex gl-flex-wrap">
        <gl-button
          :loading="loading"
          data-testid="save-cadence"
          variant="confirm"
          @click="saveAndViewList"
        >
          {{ i18n[page].save }}
        </gl-button>
        <gl-button class="gl-ml-3" data-testid="cancel-create-cadence" @click="cancel">
          {{ i18n.cancel }}
        </gl-button>
      </div>
    </gl-form>
  </article>
</template>
