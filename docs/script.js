const outputs = {
  html: '&lt;span class="hljs-keyword"&gt;let&lt;/span&gt;\nanswer = 42',
  ansi: '\\u001B[35mlet\\u001B[0m answer = 42',
  tokens: '.keyword("let")\n.plain(" answer = 42")'
};

document.querySelectorAll('.output-tab').forEach((tab) => {
  tab.addEventListener('click', () => {
    document.querySelectorAll('.output-tab').forEach((item) => {
      const selected = item === tab;
      item.classList.toggle('active', selected);
      item.setAttribute('aria-selected', selected);
    });
    document.querySelector('#output-code').innerHTML = outputs[tab.dataset.output];
  });
});

const copyButton = document.querySelector('#copy-button');
copyButton.addEventListener('click', async () => {
  const dependency = `.package(
  url: "https://github.com/yukihiratype2/swift-highlight.git",
  from: "0.1.0"
)`;
  try {
    await navigator.clipboard.writeText(dependency);
    copyButton.querySelector('.copy-label').textContent = 'Copied';
    setTimeout(() => {
      copyButton.querySelector('.copy-label').textContent = 'Copy';
    }, 1800);
  } catch {
    copyButton.querySelector('.copy-label').textContent = 'Select code';
  }
});
