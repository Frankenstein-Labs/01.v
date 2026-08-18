<script>
import { GlSprintf, GlLink } from '@gitlab/ui';

import PROJECT_CREATE_NEW_SVG_URL from '@gitlab/svgs/dist/illustrations/project-create-new-sm.svg?url';
import PROJECT_IMPORT_SVG_URL from '@gitlab/svgs/dist/illustrations/project-import-sm.svg?url';
import PROJECT_CREATE_FROM_TEMPLATE_SVG_URL from '@gitlab/svgs/dist/illustrations/project-create-from-template-sm.svg?url';
import { createAlert, VARIANT_DANGER, VARIANT_SUCCESS } from '~/alert';
import Tracking from '~/tracking';
import axios from '~/lib/utils/axios_utils';
import { s__ } from '~/locale';

export default {
  name: 'MethodStep',
  components: {
    GlLink,
    GlSprintf,
  },
  mixins: [Tracking.mixin()],
  inject: ['frameworkImportUrl'],
  emits: ['select-blank', 'select-template', 'imported'],
  computed: {
    panels() {
      const result = [
        {
          name: 'blank_framework',
          title: s__('ComplianceFramework|Create blank framework'),
          description: s__(
            'ComplianceFramework|Create a new compliance framework from scratch to define your compliance requirements.',
          ),
          imageSrc: PROJECT_CREATE_NEW_SVG_URL,
          onClick: this.selectBlank,
        },
      ];

      result.push({
        name: 'from_template',
        title: s__('ComplianceFramework|Create from template'),
        description: s__(
          'ComplianceFramework|Start from a curated template (GDPR, SOC2, …) with prefilled requirements.',
        ),
        imageSrc: PROJECT_CREATE_FROM_TEMPLATE_SVG_URL,
        onClick: this.selectTemplate,
      });

      result.push({
        name: 'import_framework',
        title: s__('ComplianceFramework|Import framework'),
        description: s__(
          'ComplianceFramework|Import an existing compliance framework from a JSON file.',
        ),
        imageSrc: PROJECT_IMPORT_SVG_URL,
        onClick: this.openImportPicker,
      });

      return result;
    },
  },
  methods: {
    selectBlank() {
      this.track('click_tab', { label: 'blank_framework' });
      this.$emit('select-blank');
    },
    selectTemplate() {
      this.track('click_tab', { label: 'from_template' });
      this.$emit('select-template');
    },
    openImportPicker() {
      this.track('click_tab', { label: 'import_framework' });
      this.$refs.fileInput.click();
    },
    async handleFileUpload(event) {
      const file = event.target.files[0];
      if (!file) return;
      if (!this.frameworkImportUrl) {
        createAlert({
          message: s__(
            'ComplianceFramework|Unable to determine the correct upload URL. Please try again.',
          ),
          variant: VARIANT_DANGER,
        });
        return;
      }

      const formData = new FormData();
      formData.append('framework_file', file);

      try {
        const response = await axios.post(this.frameworkImportUrl, formData, {
          headers: { 'Content-Type': 'multipart/form-data' },
        });

        if (!response.data.framework_id) return;

        if (response.data.message) {
          createAlert({ message: response.data.message, variant: VARIANT_DANGER });
        } else {
          createAlert({
            message: s__('ComplianceFramework|Framework imported successfully.'),
            variant: VARIANT_SUCCESS,
          });
        }

        this.$emit('imported', response.data.framework_id);
      } catch (error) {
        let errorMessage = s__('ComplianceFramework|Failed to import framework file.');
        if (error.response?.data?.message) {
          errorMessage = error.response.data.message;
        } else if (error.message) {
          errorMessage += ` ${error.message}`;
        }
        createAlert({ message: errorMessage, variant: VARIANT_DANGER });
      }
    },
  },

  complianceAdherenceTemplatesLink:
    'https://gitlab.com/gitlab-org/software-supply-chain-security/compliance/engineering/compliance-adherence-templates',
};
</script>

<template>
  <div class="gl-flex gl-flex-col">
    <section class="gl-grid gl-gap-5 @md/panel:gl-grid-cols-2">
      <button
        v-for="panel in panels"
        :key="panel.name"
        type="button"
        :data-testid="`method-${panel.name}`"
        class="gl-flex gl-cursor-pointer gl-flex-col gl-items-center gl-rounded-base gl-border-1 gl-border-solid gl-border-default gl-bg-default gl-px-3 gl-py-6 gl-text-left hover:!gl-no-underline @lg/panel:gl-flex-row"
        @click="panel.onClick"
      >
        <div class="gl-flex gl-shrink-0 gl-justify-center">
          <img aria-hidden="true" :src="panel.imageSrc" :alt="panel.title" />
        </div>
        <div class="gl-pl-4">
          <h3 class="gl-text-color-heading gl-text-size-h2">{{ panel.title }}</h3>
          <p class="gl-text-default">{{ panel.description }}</p>
        </div>
      </button>
    </section>
    <p class="gl-pt-5 gl-text-center">
      <gl-sprintf
        :message="
          s__(
            'ComplianceFramework|Need an example JSON schema? Look through our %{linkStart}examples here.%{linkEnd}',
          )
        "
      >
        <template #link="{ content }">
          <gl-link :href="$options.complianceAdherenceTemplatesLink" target="_blank">
            {{ content }}
          </gl-link>
        </template>
      </gl-sprintf>
    </p>
    <input
      ref="fileInput"
      class="gl-hidden"
      type="file"
      accept=".json"
      data-testid="method-file-input"
      @change="handleFileUpload"
    />
  </div>
</template>
