<script>
import {
  GlFormGroup,
  GlFormInput,
  GlTooltipDirective,
  GlIcon,
  GlButton,
  GlCollapsibleListbox,
} from '@gitlab/ui';

import express from '@gitlab/svgs/dist/illustrations/logos/express.svg';
import android from '@gitlab/svgs/dist/illustrations/logos/android.svg';
import spring from '@gitlab/svgs/dist/illustrations/logos/spring.svg';
import dotnetcore from '@gitlab/svgs/dist/illustrations/third-party-logos/dotnet.svg';
import rails from '@gitlab/svgs/dist/illustrations/logos/rails.svg';
import hugo from '@gitlab/svgs/dist/illustrations/logos/hugo.svg';
import astro from '@gitlab/svgs/dist/illustrations/third-party-logos/astro.svg';
import gomicro from '@gitlab/svgs/dist/illustrations/logos/gomicro.svg';
import gitlab from '@gitlab/svgs/dist/illustrations/gitlab_logo.svg';
import HelpIcon from '~/vue_shared/components/help_icon/help_icon.vue';
import TEMPLATE_DESC from 'ee/projects/default_project_templates';
import { s__ } from '~/locale';
import { DEFAULT_SELECTED_LABEL } from '../constants';

const NAMES = [
  'express',
  'android',
  'spring',
  'dotnetcore',
  'rails',
  'jsonnet',
  'hugo',
  'plainhtml',
  'astro',
  'gomicro',
];
const LOGOS = {
  express,
  android,
  spring,
  dotnetcore,
  rails,
  hugo,
  astro,
  gomicro,
  plainhtml: gitlab,
};
const TEMPLATES = NAMES.map((name) => ({
  value: name,
  text: TEMPLATE_DESC[name].text,
  logoSrc: LOGOS[name],
}));

export default {
  name: 'ProjectTemplateSelector',
  components: {
    GlFormGroup,
    GlFormInput,
    GlButton,
    GlIcon,
    GlCollapsibleListbox,
    HelpIcon,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    selectedTemplateName: {
      type: String,
      required: true,
    },
  },
  emits: ['select'],
  data() {
    return {
      selected: this.selectedTemplateName,
      selectedLogo: null,
      selectedLabel: DEFAULT_SELECTED_LABEL,
      toggleIconName: 'chevron-down',
      templates: TEMPLATES,
    };
  },
  mounted() {
    if (this.selectedTemplateName.length > 0) {
      this.selectTemplate(this.selectedTemplateName);
    }
  },
  methods: {
    selectTemplate(value) {
      this.$emit('select', value);

      const selectedItem = this.templates.find((item) => item.value === value);

      this.selectedLogo = selectedItem.logoSrc;
      this.selectedLabel = selectedItem.text;
    },
    resetTemplate() {
      this.$emit('select', '');

      this.selected = '';
      this.selectedLogo = null;
      this.selectedLabel = DEFAULT_SELECTED_LABEL;
    },
    showList() {
      this.toggleIconName = 'chevron-up';
    },
    hideList() {
      this.toggleIconName = 'chevron-down';
    },
  },
  i18n: {
    templateNameLabel: s__('ProjectsNew|Select a template'),
    templateNameOptional: s__('ProjectsNew|(optional)'),
    templateNameLabelDescription: s__(
      'ProjectsNew|Get started with one of our popular project templates.',
    ),
    templateNameTooltip: s__(
      'ProjectsNew|More templates are available after you create an account.',
    ),
  },
};
</script>
<template>
  <gl-form-group
    optional
    :label="$options.i18n.templateNameLabel"
    :optional-text="$options.i18n.templateNameOptional"
  >
    <template #label-description>
      {{ $options.i18n.templateNameLabelDescription }}

      <help-icon v-gl-tooltip :title="$options.i18n.templateNameTooltip" />
    </template>

    <gl-collapsible-listbox
      v-model="selected"
      class="gl-w-full"
      reset-button-label="Reset"
      positioning-strategy="fixed"
      :items="templates"
      :header-text="$options.i18n.templateNameLabel"
      @select="selectTemplate"
      @reset="resetTemplate"
      @shown="showList"
      @hidden="hideList"
    >
      <template #toggle>
        <gl-button class="gl-w-full" button-text-classes="gl-w-full">
          <span class="gl-flex gl-justify-between">
            <span class="gl-flex gl-items-center gl-gap-2">
              <img
                v-if="selectedLogo"
                class="gl-h-5 gl-w-5"
                data-testid="selected-logo"
                :alt="selected"
                :src="selectedLogo"
              />

              {{ selectedLabel }}
            </span>

            <gl-icon :name="toggleIconName" />
          </span>
        </gl-button>
      </template>

      <template #list-item="{ item }">
        <span class="gl-flex gl-items-center gl-gap-2">
          <img v-if="item.logoSrc" class="gl-h-5 gl-w-5" :alt="item.value" :src="item.logoSrc" />
          {{ item.text }}
        </span>
      </template>
    </gl-collapsible-listbox>

    <gl-form-input hidden name="project[template_name]" autocomplete="off" :value="selected" />
  </gl-form-group>
</template>
