import { createAlert } from '~/alert';
import axios from '~/lib/utils/axios_utils';
import { s__ } from '~/locale';

export const initTestModelConfiguration = () => {
  const button = document.getElementById('test-model-configuration-button');

  if (!button) return;

  button.addEventListener('click', (event) => {
    event.preventDefault();

    const normalText = button.innerText;

    button.disabled = true;
    button.innerText = s__('SemanticSearch|Testing...');
    createAlert({
      message: s__('SemanticSearch|Testing model configuration...'),
      variant: 'info',
    });

    const form = button.closest('form');
    const requestPath = button.getAttribute('formaction');
    const formData = new FormData(form);
    formData.delete('_method'); // Remove Rails method override for update actions

    axios
      .post(requestPath, formData)
      .then(({ data }) => {
        if (typeof data !== 'object' || data === null) {
          throw new Error(
            s__(
              'SemanticSearch|Unexpected server response. Please refresh the page and try again.',
            ),
          );
        }

        const testedModelField = document.getElementById('semantic-search-embeddings-tested-model');
        testedModelField.value = JSON.stringify(data.tested_model_metadata);

        createAlert({
          message: s__('SemanticSearch|Test successful!'),
          variant: 'success',
        });
      })
      .catch((error) => {
        const serverMessage = error.response?.data?.message;
        const message = serverMessage
          ? `${s__('SemanticSearch|Test failed')}: "${serverMessage}"`
          : error.message || String(error);
        createAlert({ message });
      })
      .finally(() => {
        button.disabled = false;
        button.innerText = normalText;
      });
  });
};
