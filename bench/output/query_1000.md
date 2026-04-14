Benchmark

Benchmark run from 2026-04-14 14:40:52.769258Z UTC

## System

Benchmark suite executing on the following system:

<table style="width: 1%">
  <tr>
    <th style="width: 1%; white-space: nowrap">Operating System</th>
    <td>macOS</td>
  </tr><tr>
    <th style="white-space: nowrap">CPU Information</th>
    <td style="white-space: nowrap">Apple M4 Pro</td>
  </tr><tr>
    <th style="white-space: nowrap">Number of Available Cores</th>
    <td style="white-space: nowrap">12</td>
  </tr><tr>
    <th style="white-space: nowrap">Available Memory</th>
    <td style="white-space: nowrap">24 GB</td>
  </tr><tr>
    <th style="white-space: nowrap">Elixir Version</th>
    <td style="white-space: nowrap">1.19.5</td>
  </tr><tr>
    <th style="white-space: nowrap">Erlang Version</th>
    <td style="white-space: nowrap">28.4.1</td>
  </tr>
</table>

## Configuration

Benchmark suite executing with the following configuration:

<table style="width: 1%">
  <tr>
    <th style="width: 1%">:time</th>
    <td style="white-space: nowrap">10 s</td>
  </tr><tr>
    <th>:parallel</th>
    <td style="white-space: nowrap">1</td>
  </tr><tr>
    <th>:warmup</th>
    <td style="white-space: nowrap">2 s</td>
  </tr>
</table>

## Statistics



Run Time

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">IPS</th>
    <th style="text-align: right">Average</th>
    <th style="text-align: right">Devitation</th>
    <th style="text-align: right">Median</th>
    <th style="text-align: right">99th&nbsp;%</th>
  </tr>

  <tr>
    <td style="white-space: nowrap">top_k=10 + filter</td>
    <td style="white-space: nowrap; text-align: right">5.50 K</td>
    <td style="white-space: nowrap; text-align: right">181.79 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;5.44%</td>
    <td style="white-space: nowrap; text-align: right">180.25 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">206.16 &micro;s</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">hnsw ef=64 top_k=10</td>
    <td style="white-space: nowrap; text-align: right">5.15 K</td>
    <td style="white-space: nowrap; text-align: right">194.30 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;10.01%</td>
    <td style="white-space: nowrap; text-align: right">193.71 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">238.13 &micro;s</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">top_k=10 + output_fields</td>
    <td style="white-space: nowrap; text-align: right">5.07 K</td>
    <td style="white-space: nowrap; text-align: right">197.32 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;9.65%</td>
    <td style="white-space: nowrap; text-align: right">193.42 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">222.50 &micro;s</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">top_k=10</td>
    <td style="white-space: nowrap; text-align: right">4.68 K</td>
    <td style="white-space: nowrap; text-align: right">213.47 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;7.31%</td>
    <td style="white-space: nowrap; text-align: right">212.88 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">266.68 &micro;s</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">top_k=100</td>
    <td style="white-space: nowrap; text-align: right">0.77 K</td>
    <td style="white-space: nowrap; text-align: right">1294.13 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;3.36%</td>
    <td style="white-space: nowrap; text-align: right">1292 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">1363.07 &micro;s</td>
  </tr>

</table>


Run Time Comparison

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">IPS</th>
    <th style="text-align: right">Slower</th>
  <tr>
    <td style="white-space: nowrap">top_k=10 + filter</td>
    <td style="white-space: nowrap;text-align: right">5.50 K</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">hnsw ef=64 top_k=10</td>
    <td style="white-space: nowrap; text-align: right">5.15 K</td>
    <td style="white-space: nowrap; text-align: right">1.07x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">top_k=10 + output_fields</td>
    <td style="white-space: nowrap; text-align: right">5.07 K</td>
    <td style="white-space: nowrap; text-align: right">1.09x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">top_k=10</td>
    <td style="white-space: nowrap; text-align: right">4.68 K</td>
    <td style="white-space: nowrap; text-align: right">1.17x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">top_k=100</td>
    <td style="white-space: nowrap; text-align: right">0.77 K</td>
    <td style="white-space: nowrap; text-align: right">7.12x</td>
  </tr>

</table>



Memory Usage

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">Average</th>
    <th style="text-align: right">Factor</th>
  </tr>
  <tr>
    <td style="white-space: nowrap">top_k=10 + filter</td>
    <td style="white-space: nowrap">4.80 KB</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">hnsw ef=64 top_k=10</td>
    <td style="white-space: nowrap">4.81 KB</td>
    <td>1.0x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">top_k=10 + output_fields</td>
    <td style="white-space: nowrap">4.03 KB</td>
    <td>0.84x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">top_k=10</td>
    <td style="white-space: nowrap">4.80 KB</td>
    <td>1.0x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">top_k=100</td>
    <td style="white-space: nowrap">35.74 KB</td>
    <td>7.44x</td>
  </tr>
</table>