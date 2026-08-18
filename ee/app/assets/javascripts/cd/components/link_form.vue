<script>
import { uniqueId } from 'lodash-es';
import { GlButton, GlFormGroup, GlFormSelect, GlFormInput } from '@gitlab/ui';
import { DEFAULT_LINK_TYPE, LINK_TYPES } from '../constants';

export default {
  name: 'LinkForm',
  components: {
    GlButton,
    GlFormGroup,
    GlFormSelect,
    GlFormInput,
  },
  props: {
    link: {
      type: Object,
      required: false,
      default: null,
    },
    submitting: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['submit', 'cancel'],
  data() {
    return {
      linkType: this.link?.linkType ?? DEFAULT_LINK_TYPE,
      name: this.link?.name ?? '',
      url: this.link?.url ?? '',
      urlPlaceholder: 'https://…',
      typeId: uniqueId('link-type-'),
      titleId: uniqueId('link-title-'),
      urlId: uniqueId('link-url-'),
    };
  },
  computed: {
    isEditing() {
      return Boolean(this.link);
    },
    typeOptions() {
      return LINK_TYPES.map(({ value, label }) => ({ value, text: label }));
    },
    urlState() {
      if (!this.url || this.isValidLink(this.url)) {
        return null;
      }
      return false;
    },
    isValid() {
      return Boolean(this.name && this.isValidLink(this.url));
    },
  },
  methods: {
    isValidLink(value) {
      let parsed;
      try {
        parsed = new URL(value);
      } catch {
        return false;
      }
      return ['http:', 'https:'].includes(parsed.protocol);
    },
    onSubmit() {
      if (!this.isValid) {
        return;
      }

      this.$emit('submit', {
        linkType: this.linkType,
        name: this.name,
        url: this.url,
      });
    },
  },
};
</script>

<template>
  <form
    data-testid="link-form"
    class="gl-rounded-lg gl-border-1 gl-border-solid gl-border-default gl-bg-default gl-px-4 gl-py-4"
    @submit.prevent="onSubmit"
  >
    <gl-form-group
      :label="s__('ContinuousDeployment|Type')"
      :label-for="typeId"
      label-cols="1"
      label-class="gl-flex gl-items-center !gl-pb-0 !gl-text-subtle !gl-text-sm"
      class="gl-mb-3"
    >
      <gl-form-select :id="typeId" v-model="linkType" :options="typeOptions" />
    </gl-form-group>

    <gl-form-group
      :label="s__('ContinuousDeployment|Title')"
      :label-for="titleId"
      label-cols="1"
      label-class="gl-flex gl-items-center !gl-pb-0 !gl-text-subtle !gl-text-sm"
      class="gl-mb-3"
    >
      <gl-form-input
        :id="titleId"
        v-model.trim="name"
        :placeholder="s__('ContinuousDeployment|e.g. Grafana — Payments overview')"
      />
    </gl-form-group>

    <gl-form-group
      :label="s__('ContinuousDeployment|URL')"
      :label-for="urlId"
      label-cols="1"
      label-class="gl-flex gl-items-center !gl-pb-0 !gl-text-subtle !gl-text-sm"
      :state="urlState"
      :invalid-feedback="
        s__('ContinuousDeployment|Enter a valid URL that starts with http:// or https://')
      "
      class="gl-mb-3"
    >
      <gl-form-input
        :id="urlId"
        v-model.trim="url"
        :state="urlState"
        :placeholder="urlPlaceholder"
      />
    </gl-form-group>

    <div class="gl-flex gl-justify-end gl-gap-3">
      <gl-button
        type="submit"
        variant="confirm"
        size="small"
        :disabled="!isValid"
        :loading="submitting"
        data-testid="submit-link-button"
      >
        {{
          isEditing
            ? s__('ContinuousDeployment|Save changes')
            : s__('ContinuousDeployment|Add link')
        }}
      </gl-button>
      <gl-button size="small" data-testid="cancel-link-button" @click="$emit('cancel')">
        {{ __('Cancel') }}
      </gl-button>
    </div>
  </form>
</template>
