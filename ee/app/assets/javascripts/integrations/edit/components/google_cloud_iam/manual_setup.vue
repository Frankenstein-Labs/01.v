<script>
import { defineAsyncComponent } from 'vue';
import { GlButton, GlIcon, GlLink, GlSprintf, GlModal } from '@gitlab/ui';
import { __ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';

import ClipboardButton from '~/vue_shared/components/clipboard_button.vue';
import SettingsSection from '~/vue_shared/components/settings/settings_section.vue';

export default {
  name: 'ManualSetup',
  components: {
    GlButton,
    GlIcon,
    GlLink,
    GlModal,
    GlSprintf,
    InviteMembersTrigger: defineAsyncComponent(
      () => import('~/invite_members/components/invite_members_trigger.vue'),
    ),
    ClipboardButton,
    SettingsSection,
  },
  props: {
    wlifIssuer: {
      type: String,
      required: true,
    },
    helpTextPoolId: {
      type: String,
      required: false,
      default: 'gitlab-pool',
    },
  },
  data() {
    return {
      modalVisible: false,
    };
  },
  methods: {
    toggleModal() {
      this.modalVisible = !this.modalVisible;
    },
  },
  modalActions: {
    cancel: {
      text: __('Close'),
    },
  },
  // We need an absolute URL so that not only the path is copied.
  helpURL: new URL(
    helpPagePath('integration/google_cloud_iam', {
      anchor: 'with-the-google-cloud-cli',
    }),
    window.location.href,
  ).href,
};
</script>

<template>
  <settings-section
    :heading="s__('GoogleCloud|1. Connection')"
    :description="
      s__(
        'GoogleCloud|To connect to a Google Cloud project, it must have a specific configuration of workload identity federation that you can set up in the next step. To improve security, the project should be just for identity management.',
      )
    "
  >
    <gl-button variant="link" @click="toggleModal">
      {{ s__('GoogleCloud|What if I cannot manage workload identity federation in Google Cloud?') }}
    </gl-button>
    <gl-modal
      v-model="modalVisible"
      modal-id="google-cloud-iam-non-admin-instructions"
      :title="s__('GoogleCloud|If you cannot manage workload identity federation in Google Cloud')"
      :action-cancel="$options.modalActions.cancel"
      no-enforce-focus
    >
      <p class="gl-mb-4">
        <gl-sprintf
          :message="
            s__(
              'GoogleCloud|If you don\'t have the %{linkStart}permissions%{linkEnd} to create workload identity pools and providers in Google Cloud:',
            )
          "
        >
          <template #link="{ content }">
            <gl-link
              target="_blank"
              href="https://cloud.google.com/iam/docs/manage-workload-identity-pools-providers#required-roles"
            >
              {{ content }}
              <gl-icon name="external-link" :aria-label="__('(external link)')" />
            </gl-link>
          </template>
        </gl-sprintf>
      </p>
      <ol>
        <li>
          <gl-sprintf
            :message="
              s__(
                'GoogleCloud|Share the following information with someone that can manage workload identity federation or %{linkStart}invite them%{linkEnd} to set up this integration.',
              )
            "
          >
            <template #link="{ content }">
              <invite-members-trigger
                :display-text="content"
                class="gl-align-baseline"
                variant="link"
                trigger-source="google_cloud_iam_setup"
              />
            </template>
          </gl-sprintf>
          <ol type="a">
            <li>
              <gl-link :href="$options.helpURL">{{
                s__('GoogleCloud|Setup instructions')
              }}</gl-link>
              <clipboard-button
                :text="$options.helpURL"
                :title="s__('GoogleCloud|Copy instructions URL')"
                category="tertiary"
                size="small"
              />
            </li>
            <li>
              <gl-sprintf :message="s__('GoogleCloud|Your identity provider issuer: %{issuer}')">
                <template #issuer>
                  <code>{{ wlifIssuer }}</code>
                </template>
              </gl-sprintf>
              <clipboard-button
                :text="wlifIssuer"
                :title="s__('GoogleCloud|Copy issuer')"
                category="tertiary"
                size="small"
              />
            </li>
            <li>
              <gl-sprintf
                :message="s__('GoogleCloud|Recommended pool and provider id: %{providerId}')"
              >
                <template #providerId>
                  <code>{{ helpTextPoolId }}</code>
                </template>
              </gl-sprintf>
              <clipboard-button
                :text="helpTextPoolId"
                :title="s__('GoogleCloud|Copy ID')"
                category="tertiary"
                size="small"
              />
            </li>
          </ol>
        </li>
        <li>
          {{
            s__(
              'GoogleCloud|After the Google Cloud workload identity federation has been set up, complete the fields in the integration.',
            )
          }}
        </li>
      </ol>
    </gl-modal>
  </settings-section>
</template>
