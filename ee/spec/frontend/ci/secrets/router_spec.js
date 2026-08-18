import SecretDetailsWrapper from 'ee/ci/secrets/components/secret_details/secret_details_wrapper.vue';
import SecretFormWrapper from 'ee/ci/secrets/components/secret_form/secret_form_wrapper.vue';
import SecretsTable from 'ee/ci/secrets/components/secrets_table/secrets_table.vue';
import createRouter from 'ee/ci/secrets/router';
import { getMatchedComponents } from '~/lib/utils/vue3compat/vue_router';

describe('Secrets router', () => {
  let router;

  const base = '/-/secrets';

  it.each`
    path                     | componentNames            | components
    ${'/'}                   | ${'SecretsTable'}         | ${[SecretsTable]}
    ${'/?page=2'}            | ${'SecretsTable'}         | ${[SecretsTable]}
    ${'/new'}                | ${'SecretFormWrapper'}    | ${[SecretFormWrapper]}
    ${'/secretName/details'} | ${'SecretDetailsWrapper'} | ${[SecretDetailsWrapper]}
    ${'/secretName/edit'}    | ${'SecretFormWrapper'}    | ${[SecretFormWrapper]}
  `('uses $componentNames for path "$path"', ({ path, components }) => {
    router = createRouter(base);
    const componentsForRoute = getMatchedComponents(router, path);

    expect(componentsForRoute).toStrictEqual(components);
  });

  it.each`
    path                          | redirect
    ${'/secretName'}              | ${'details'}
    ${'/secretName/unknownroute'} | ${'index'}
  `('redirects from $path to $redirect', async ({ path, redirect }) => {
    router = createRouter(base);

    await router.push(path);

    expect(router.currentRoute.name).toBe(redirect);
  });
});
