Benchmark

Benchmark run from 2026-04-14 14:44:28.502239Z UTC

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
    <td style="white-space: nowrap">ef=16</td>
    <td style="white-space: nowrap; text-align: right">5.38 K</td>
    <td style="white-space: nowrap; text-align: right">185.73 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;27.72%</td>
    <td style="white-space: nowrap; text-align: right">182.00 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">261.14 &micro;s</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">ef=32</td>
    <td style="white-space: nowrap; text-align: right">5.25 K</td>
    <td style="white-space: nowrap; text-align: right">190.65 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;8.79%</td>
    <td style="white-space: nowrap; text-align: right">187.38 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">221.33 &micro;s</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">ef=64</td>
    <td style="white-space: nowrap; text-align: right">4.77 K</td>
    <td style="white-space: nowrap; text-align: right">209.49 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;5.60%</td>
    <td style="white-space: nowrap; text-align: right">206.21 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">243.08 &micro;s</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">ef=128</td>
    <td style="white-space: nowrap; text-align: right">3.85 K</td>
    <td style="white-space: nowrap; text-align: right">259.92 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;13.72%</td>
    <td style="white-space: nowrap; text-align: right">254.08 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">414.16 &micro;s</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">ef=256</td>
    <td style="white-space: nowrap; text-align: right">3.34 K</td>
    <td style="white-space: nowrap; text-align: right">299.32 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;6.84%</td>
    <td style="white-space: nowrap; text-align: right">294.42 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">353.67 &micro;s</td>
  </tr>

</table>


Run Time Comparison

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">IPS</th>
    <th style="text-align: right">Slower</th>
  <tr>
    <td style="white-space: nowrap">ef=16</td>
    <td style="white-space: nowrap;text-align: right">5.38 K</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">ef=32</td>
    <td style="white-space: nowrap; text-align: right">5.25 K</td>
    <td style="white-space: nowrap; text-align: right">1.03x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">ef=64</td>
    <td style="white-space: nowrap; text-align: right">4.77 K</td>
    <td style="white-space: nowrap; text-align: right">1.13x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">ef=128</td>
    <td style="white-space: nowrap; text-align: right">3.85 K</td>
    <td style="white-space: nowrap; text-align: right">1.4x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">ef=256</td>
    <td style="white-space: nowrap; text-align: right">3.34 K</td>
    <td style="white-space: nowrap; text-align: right">1.61x</td>
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
    <td style="white-space: nowrap">ef=16</td>
    <td style="white-space: nowrap">4.80 KB</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">ef=32</td>
    <td style="white-space: nowrap">4.80 KB</td>
    <td>1.0x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">ef=64</td>
    <td style="white-space: nowrap">4.80 KB</td>
    <td>1.0x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">ef=128</td>
    <td style="white-space: nowrap">4.80 KB</td>
    <td>1.0x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">ef=256</td>
    <td style="white-space: nowrap">4.80 KB</td>
    <td>1.0x</td>
  </tr>
</table>