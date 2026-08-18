import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { TYPENAME_PROJECT, TYPENAME_USER } from '~/graphql_shared/constants';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import createDefaultClient from '~/lib/graphql';
import { updateText } from '~/lib/utils/text_markdown';
import { s__ } from '~/locale';
import GenerateDescriptionModal from '../components/ai_generate_issue_description.vue';

let el;

function initDescriptionModal({
  resourceId = convertToGraphQLId(TYPENAME_PROJECT, document.body.dataset.projectId),
} = {}) {
  if (!el) {
    el = document.createElement('div');
    document.body.appendChild(el);
  }

  Vue.use(VueApollo);

  const apolloProvider = new VueApollo({
    defaultClient: createDefaultClient(),
  });

  const userId = convertToGraphQLId(TYPENAME_USER, gon.current_user_id);

  return new Vue({
    el,
    name: 'GenerateDescriptionModalRoot',
    apolloProvider,
    render: (createElement) =>
      createElement(GenerateDescriptionModal, {
        props: {
          userId,
          resourceId,
        },
        class: 'gl-mb-5',
        on: {
          'content-generated': function contentGenerated(description) {
            const textArea =
              document.querySelector('#issue_description') ||
              document.querySelector('#work-item-description');
            textArea.value = '';

            updateText({
              textArea,
              tag: description,
              cursorOffset: 0,
              wrap: false,
            });
          },
        },
      }),
  });
}

export const generateDescriptionAction = ({ resourceId } = {}) => ({
  title: s__('AI|Generate issue description'),
  description: s__('AI|Create issue description based on a short prompt'),
  handler() {
    initDescriptionModal({ resourceId });

    return Promise.resolve(null);
  },
});
