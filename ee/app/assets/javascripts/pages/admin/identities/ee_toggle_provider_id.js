function toggleGroupVisibility(providerValue) {
  const show = providerValue === 'group_saml';
  document.querySelector('.js-providerId-group').classList.toggle('gl-hidden', !show);
}

export function toggleProviderIdGroup() {
  const provider = document.getElementById('identity_provider');
  toggleGroupVisibility(provider.value);

  provider.addEventListener('change', (event) => {
    const providerValue = event.target.value;
    toggleGroupVisibility(providerValue);
  });
}
