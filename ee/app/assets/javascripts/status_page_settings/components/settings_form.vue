<script>
import {
  GlButton,
  GlSprintf,
  GlLink,
  GlIcon,
  GlFormGroup,
  GlFormInput,
  GlFormCheckbox,
} from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapActions, mapState } from 'vuex';
import { helpPagePath } from '~/helpers/help_page_helper';
import SettingsBlock from '~/vue_shared/components/settings/settings_block.vue';
import { __, s__ } from '~/locale';
import { mapComputed } from '~/vuex_shared/bindings';

export default {
  name: 'SettingsForm',
  components: {
    GlButton,
    GlSprintf,
    GlLink,
    GlFormGroup,
    GlFormInput,
    GlIcon,
    GlFormCheckbox,
    SettingsBlock,
  },
  i18n: {
    headerText: s__('StatusPage|Status page'),
    expandBtnLabel: __('Expand'),
    saveBtnLabel: __('Save changes'),
    subHeaderText: s__(
      'StatusPage|Configure file storage settings to link issues in this project to an external status page.',
    ),
    introText: s__(
      'StatusPage|To publish incidents to an external status page, GitLab stores a JSON file in your Amazon S3 account at a location that your external status page service can access. Make sure to also set up %{docsLink}',
    ),
    introLinkText: s__('StatusPage|your status page frontend.'),
    activeLabel: s__('StatusPage|Active'),
    url: {
      label: s__('StatusPage|Status page URL'),
      linkText: __('Configuration help'),
    },
    bucket: {
      label: s__('StatusPage|S3 Bucket name'),
      helpText: s__('StatusPage|Bucket %{docsLink}'),
      linkText: s__('StatusPage|configuration documentation'),
    },
    region: {
      label: s__('StatusPage|AWS region'),
      helpText: s__('StatusPage|AWS %{docsLink}'),
      linkText: s__('StatusPage|configuration documentation'),
    },
    accessKey: {
      label: s__('StatusPage|AWS access key ID'),
    },
    secretAccessKey: {
      label: s__('StatusPage|AWS Secret access key'),
    },
  },
  computed: {
    ...mapState(['loading']),
    ...mapComputed([
      { key: 'enabled', updateFn: 'setStatusPageEnabled' },
      { key: 'url', updateFn: 'setStatusPageUrl' },
      { key: 'bucketName', updateFn: 'setStatusPageBucketName' },
      { key: 'region', updateFn: 'setStatusPageRegion' },
      { key: 'awsAccessKey', updateFn: 'setStatusPageAccessKey' },
      { key: 'awsSecretKey', updateFn: 'setStatusPageSecretAccessKey' },
    ]),
    statusPageHelpUrl() {
      return helpPagePath('/operations/incident_management/status_page', {
        anchor: 'configure-gitlab-with-cloud-provider-information',
      });
    },
  },
  methods: {
    ...mapActions(['updateStatusPageSettings']),
  },
};
</script>

<template>
  <settings-block
    id="status-page"
    :title="$options.i18n.headerText"
    class="js-status-page-settings"
  >
    <template #description>
      <span ref="sectionSubHeader">{{ $options.i18n.subHeaderText }}</span>
    </template>

    <template #default>
      <!-- eslint-disable @gitlab/vue-require-i18n-attribute-strings -->
      <p>
        <gl-sprintf :message="$options.i18n.introText">
          <template #docsLink>
            <gl-link target="_blank" :href="statusPageHelpUrl">
              <span>{{ $options.i18n.introLinkText }}</span>
            </gl-link>
          </template>
        </gl-sprintf>
      </p>
      <form ref="settingsForm" @submit.prevent="updateStatusPageSettings">
        <gl-form-group class="!gl-mb-5 gl-pl-0">
          <gl-form-checkbox v-model="enabled">
            <span class="gl-font-bold">{{ $options.i18n.activeLabel }}</span></gl-form-checkbox
          >
        </gl-form-group>

        <gl-form-group
          :label="$options.i18n.url.label"
          label-size="sm"
          label-for="status-page-url"
          class="gl-col-8 gl-col-md-9 !gl-mb-5 gl-pl-0"
        >
          <gl-form-input id="status-page-url" v-model="url" />
          <p class="form-text gl-text-subtle">
            <gl-link target="_blank" :href="statusPageHelpUrl">
              {{ $options.i18n.url.linkText }}
            </gl-link>
          </p>
        </gl-form-group>

        <gl-form-group
          :label="$options.i18n.bucket.label"
          label-size="sm"
          label-for="status-page-s3-bucket-name"
          class="gl-col-8 gl-col-md-9 !gl-mb-5 gl-pl-0"
        >
          <gl-form-input id="status-page-s3-bucket-name" v-model="bucketName" />
          <p class="form-text gl-text-subtle">
            <gl-sprintf :message="$options.i18n.bucket.helpText">
              <template #docsLink>
                <gl-link
                  target="_blank"
                  href="https://docs.aws.amazon.com/AmazonS3/latest/dev/HostingWebsiteOnS3Setup.html"
                >
                  <span>{{ $options.i18n.bucket.linkText }}</span>
                  <gl-icon
                    name="external-link"
                    :aria-label="__('(external link)')"
                    class="vertical-align-middle"
                  />
                </gl-link>
              </template>
            </gl-sprintf>
          </p>
        </gl-form-group>

        <gl-form-group
          :label="$options.i18n.region.label"
          label-size="sm"
          label-for="status-page-aws-region"
          class="gl-col-8 gl-col-md-9 !gl-mb-5 gl-pl-0"
        >
          <gl-form-input
            id="status-page-aws-region"
            v-model="region"
            placeholder="example: us-west-2"
          />
          <p class="form-text gl-text-subtle">
            <gl-sprintf :message="$options.i18n.region.helpText">
              <template #docsLink>
                <gl-link href="https://github.com/aws/aws-sdk-ruby#configuration" target="_blank">
                  <span>{{ $options.i18n.region.linkText }}</span>
                  <gl-icon
                    name="external-link"
                    :aria-label="__('(external link)')"
                    class="vertical-align-middle"
                  />
                </gl-link>
              </template>
            </gl-sprintf>
          </p>
        </gl-form-group>

        <gl-form-group
          :label="$options.i18n.accessKey.label"
          label-size="sm"
          label-for="status-page-aws-access-key"
          class="gl-col-8 gl-col-md-9 !gl-mb-5 gl-pl-0"
        >
          <gl-form-input id="status-page-aws-access-key" v-model="awsAccessKey" />
        </gl-form-group>

        <gl-form-group
          :label="$options.i18n.secretAccessKey.label"
          label-size="sm"
          label-for="status-page-aws-secret-access-key"
          class="gl-col-8 gl-col-md-9 !gl-mb-5 gl-pl-0"
        >
          <gl-form-input id="status-page-aws-secret-access-key" v-model="awsSecretKey" />
        </gl-form-group>
        <gl-button
          ref="submitBtn"
          :disabled="loading"
          variant="confirm"
          category="primary"
          type="submit"
          class="js-no-auto-disable"
        >
          {{ $options.i18n.saveBtnLabel }}
        </gl-button>
      </form>
    </template>
  </settings-block>
</template>
