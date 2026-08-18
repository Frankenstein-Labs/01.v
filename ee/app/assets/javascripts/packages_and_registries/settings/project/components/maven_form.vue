<script>
import { GlFormGroup, GlFormInput, GlSprintf } from '@gitlab/ui';
import CrudComponent from '~/vue_shared/components/crud_component.vue';

export default {
  name: 'MavenForm',
  components: {
    GlFormGroup,
    GlFormInput,
    GlSprintf,
    CrudComponent,
  },
  props: {
    value: {
      type: Object,
      required: true,
    },
  },
  emits: ['input'],
  methods: {
    onModelChange(newValue, model) {
      this.$emit('input', { ...this.value, [model]: newValue });
    },
  },
};
</script>

<template>
  <crud-component :title="s__('PackageRegistry|Configure external Maven registry')" class="gl-mt-4">
    <div
      class="gl-mt-4 gl-flex gl-flex-col gl-gap-5 @md/panel:gl-flex-row @md/panel:gl-justify-between"
    >
      <gl-form-group :label="__('URL')" label-for="maven-url" class="gl-grow gl-basis-0">
        <template #description>
          <span data-testid="url-field-description">
            <gl-sprintf
              :message="
                s__(
                  'DependencyProxy|Base URL of the external registry. Must begin with %{codeStart}http%{codeEnd} or %{codeStart}https%{codeEnd}',
                )
              "
            >
              <template #code="{ content }">
                <code>{{ content }}</code>
              </template>
            </gl-sprintf>
          </span>
        </template>
        <gl-form-input
          id="maven-url"
          :value="value.mavenExternalRegistryUrl"
          width="xl"
          @input="onModelChange($event.trim(), 'mavenExternalRegistryUrl')"
        />
      </gl-form-group>
      <gl-form-group
        :label="__('Username')"
        :description="s__('DependencyProxy|Username of the external registry.')"
        label-for="maven-username"
        class="gl-grow gl-basis-0"
      >
        <gl-form-input
          id="maven-username"
          :value="value.mavenExternalRegistryUsername"
          width="xl"
          @input="onModelChange($event.trim(), 'mavenExternalRegistryUsername')"
        />
      </gl-form-group>
      <gl-form-group
        :label="__('Password')"
        :description="s__('DependencyProxy|Password of the external registry.')"
        label-for="maven-password"
        class="gl-grow gl-basis-0"
      >
        <gl-form-input
          id="maven-password"
          :value="value.mavenExternalRegistryPassword"
          type="password"
          width="xl"
          @input="onModelChange($event, 'mavenExternalRegistryPassword')"
        />
      </gl-form-group>
    </div>
  </crud-component>
</template>
