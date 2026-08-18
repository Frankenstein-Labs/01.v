<script>
import { GlAlert, GlBadge, GlButton, GlLoadingIcon } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { s__, n__ } from '~/locale';
import complianceFrameworkTemplatesQuery from '../graphql/compliance_framework_templates.query.graphql';
import TemplateInfoDrawer from '../components/template_info_drawer.vue';

const parseRequirements = (template) => {
  try {
    const parsed = JSON.parse(template.json);
    return parsed?.requirements ?? [];
  } catch (error) {
    Sentry.captureException(error);
    return [];
  }
};

export default {
  name: 'TemplateStep',
  components: { GlAlert, GlBadge, GlButton, GlLoadingIcon, TemplateInfoDrawer },
  emits: ['template-selected'],
  i18n: {
    heading: s__('ComplianceFramework|Choose a template'),
    description: s__(
      'ComplianceFramework|Select a template to prefill basic information and requirements.',
    ),
    fetchError: s__('ComplianceFramework|Failed to load compliance framework templates.'),
    empty: s__('ComplianceFramework|No compliance framework templates are available.'),
    useTemplate: s__('ComplianceFramework|Use template'),
    viewDetails: s__('ComplianceFramework|View details'),
  },
  apollo: {
    templates: {
      query: complianceFrameworkTemplatesQuery,
      update(data) {
        return data?.complianceFrameworkTemplates ?? [];
      },
      error(error) {
        this.errorMessage = this.$options.i18n.fetchError;
        Sentry.captureException(error);
      },
    },
  },
  data() {
    return {
      templates: [],
      errorMessage: '',
      previewTemplateId: null,
    };
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.templates.loading;
    },
    isEmpty() {
      return !this.isLoading && !this.errorMessage && this.templates.length === 0;
    },
    enrichedTemplates() {
      return this.templates.map((template) => {
        const requirements = parseRequirements(template);
        const controlCount = requirements.reduce(
          (sum, requirement) => sum + (requirement.controls?.length ?? 0),
          0,
        );
        return {
          ...template,
          requirements,
          requirementCount: requirements.length,
          controlCount,
        };
      });
    },
    previewTemplate() {
      return this.enrichedTemplates.find((t) => t.id === this.previewTemplateId) ?? null;
    },
  },
  methods: {
    requirementsLabel(count) {
      return n__('%d requirement', '%d requirements', count);
    },
    controlsLabel(count) {
      return n__('%d control', '%d controls', count);
    },
    onSelect(template) {
      this.previewTemplateId = null;
      this.$emit('template-selected', {
        id: template.id,
        name: template.name,
        description: template.description,
        color: template.color,
        requirements: template.requirements,
      });
    },
    onViewDetails(template) {
      this.previewTemplateId = template.id;
    },
    closeDrawer() {
      this.previewTemplateId = null;
    },
  },
};
</script>

<template>
  <div>
    <h3 class="gl-heading-3">{{ $options.i18n.heading }}</h3>
    <p class="gl-text-subtle">{{ $options.i18n.description }}</p>

    <gl-loading-icon v-if="isLoading" size="lg" class="gl-py-6" />

    <gl-alert
      v-else-if="errorMessage"
      variant="danger"
      :dismissible="false"
      data-testid="template-step-error"
      >{{ errorMessage }}</gl-alert
    >

    <p v-else-if="isEmpty" data-testid="template-step-empty" class="gl-text-subtle">
      {{ $options.i18n.empty }}
    </p>

    <section v-else class="gl-grid gl-gap-5 @md/panel:gl-grid-cols-2">
      <div
        v-for="template in enrichedTemplates"
        :key="template.id"
        :data-testid="`template-${template.id}`"
        class="gl-flex gl-flex-col gl-rounded-base gl-border-1 gl-border-solid gl-border-default gl-bg-default gl-px-4 gl-py-5"
      >
        <h4 class="gl-leading-none gl-mb-0 gl-flex gl-items-center gl-gap-3 gl-text-size-h2">
          <span
            class="gl-inline-block gl-h-4 gl-w-4 gl-shrink-0 gl-rounded-full"
            :style="{ backgroundColor: template.color }"
            aria-hidden="true"
          ></span>
          <span>{{ template.name }}</span>
        </h4>
        <div class="gl-mt-3 gl-flex gl-flex-wrap gl-gap-2">
          <gl-badge data-testid="requirements-badge">{{
            requirementsLabel(template.requirementCount)
          }}</gl-badge>
          <gl-badge data-testid="controls-badge">{{
            controlsLabel(template.controlCount)
          }}</gl-badge>
        </div>
        <p class="gl-mb-0 gl-mt-3 gl-grow gl-text-default">{{ template.description }}</p>
        <div class="gl-mt-4 gl-flex gl-flex-wrap gl-gap-3">
          <gl-button variant="confirm" data-testid="use-template-btn" @click="onSelect(template)">{{
            $options.i18n.useTemplate
          }}</gl-button>
          <gl-button data-testid="view-details-btn" @click="onViewDetails(template)">{{
            $options.i18n.viewDetails
          }}</gl-button>
        </div>
      </div>
    </section>

    <template-info-drawer
      :template="previewTemplate"
      @close="closeDrawer"
      @use-template="onSelect"
    />
  </div>
</template>
