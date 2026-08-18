<script>
import { GlFormCheckbox, GlIcon, GlPopover, GlLink, GlSprintf } from '@gitlab/ui';
import { s__ } from '~/locale';
import { parseBoolean } from '~/lib/utils/common_utils';
import glLicensedFeaturesMixin from '~/vue_shared/mixins/gl_licensed_features_mixin';
import { PRIVATE_PROFILES_DISABLED_ICON, PRIVATE_PROFILES_DISABLED_HELP_LINK } from '../constants';

export default {
  name: 'PrivateProfileRestrictions',
  i18n: {
    defaultToPrivateProfiles: s__("AdminSettings|Make new users' profiles private by default"),
    allowPrivateProfiles: s__('AdminSettings|Allow users to make their profiles private'),
    privateProfilesDisabledPopoverTitle: s__('AdminSettings|Setting locked'),
    privateProfilesDisabledPopoverInfo: s__(
      'AdminSettings|The option to make profiles private has been disabled. Profiles are required to be public in this instance, and cannot be set to private by default. %{linkStart}Learn more%{linkEnd}.',
    ),
  },
  components: {
    GlFormCheckbox,
    GlIcon,
    GlPopover,
    GlLink,
    GlSprintf,
  },
  mixins: [glLicensedFeaturesMixin()],
  props: {
    defaultToPrivateProfiles: {
      type: Object,
      required: true,
    },
    allowPrivateProfiles: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      defaultToPrivateProfilesValue: parseBoolean(this.defaultToPrivateProfiles.value),
      allowPrivateProfilesValue: parseBoolean(this.allowPrivateProfiles.value),
    };
  },
  computed: {
    disablePrivateProfilesFeatureEnabled() {
      return this.glLicensedFeatures.disablePrivateProfiles;
    },
    privateProfilesDisabled() {
      return this.disablePrivateProfilesFeatureEnabled && !this.allowPrivateProfilesValue;
    },
  },
  methods: {
    allowPrivateProfilesChanged(val) {
      if (!val) {
        this.defaultToPrivateProfilesValue = false;
      }
    },
  },
  PRIVATE_PROFILES_DISABLED_ICON,
  PRIVATE_PROFILES_DISABLED_HELP_LINK,
};
</script>

<template>
  <div>
    <template v-if="disablePrivateProfilesFeatureEnabled">
      <!-- This hidden field allows for unchecked checkboxes to be submitted to HTML form -->
      <!-- https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input/checkbox#sect2 -->
      <input
        type="hidden"
        :name="allowPrivateProfiles.name"
        value="0"
        :data-testid="`${allowPrivateProfiles.id}-hidden`"
      />
      <gl-form-checkbox
        :id="allowPrivateProfiles.id"
        v-model="allowPrivateProfilesValue"
        :name="allowPrivateProfiles.name"
        :data-testid="allowPrivateProfiles.id"
        @input="allowPrivateProfilesChanged"
      >
        {{ $options.i18n.allowPrivateProfiles }}
      </gl-form-checkbox>
    </template>

    <!-- This hidden field allows for unchecked checkboxes to be submitted to HTML form -->
    <!-- https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input/checkbox#sect2 -->
    <input
      type="hidden"
      :name="defaultToPrivateProfiles.name"
      value="0"
      :data-testid="`${defaultToPrivateProfiles.id}-hidden`"
    />
    <gl-form-checkbox
      :id="defaultToPrivateProfiles.id"
      v-model="defaultToPrivateProfilesValue"
      :name="defaultToPrivateProfiles.name"
      :disabled="privateProfilesDisabled"
      :data-testid="defaultToPrivateProfiles.id"
    >
      {{ $options.i18n.defaultToPrivateProfiles }}

      <template v-if="privateProfilesDisabled">
        <gl-icon :id="$options.PRIVATE_PROFILES_DISABLED_ICON" name="lock" />
        <gl-popover :target="$options.PRIVATE_PROFILES_DISABLED_ICON" placement="top">
          <template #title> {{ $options.i18n.privateProfilesDisabledPopoverTitle }} </template>
          <slot>
            <gl-sprintf :message="$options.i18n.privateProfilesDisabledPopoverInfo">
              <template #link="{ content }">
                <gl-link :href="$options.PRIVATE_PROFILES_DISABLED_HELP_LINK">{{
                  content
                }}</gl-link>
              </template>
            </gl-sprintf>
          </slot>
        </gl-popover>
      </template>
    </gl-form-checkbox>
  </div>
</template>
