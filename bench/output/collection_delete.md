Benchmark

Benchmark run from 2026-04-14 14:39:17.224411Z UTC

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
    <td style="white-space: nowrap">5 s</td>
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
    <td style="white-space: nowrap">delete 100 by pk</td>
    <td style="white-space: nowrap; text-align: right">18.13 K</td>
    <td style="white-space: nowrap; text-align: right">55.16 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;15.23%</td>
    <td style="white-space: nowrap; text-align: right">53.75 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">88.21 &micro;s</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">delete_by_filter</td>
    <td style="white-space: nowrap; text-align: right">12.61 K</td>
    <td style="white-space: nowrap; text-align: right">79.32 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;23.55%</td>
    <td style="white-space: nowrap; text-align: right">77.63 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">133.33 &micro;s</td>
  </tr>

</table>


Run Time Comparison

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">IPS</th>
    <th style="text-align: right">Slower</th>
  <tr>
    <td style="white-space: nowrap">delete 100 by pk</td>
    <td style="white-space: nowrap;text-align: right">18.13 K</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">delete_by_filter</td>
    <td style="white-space: nowrap; text-align: right">12.61 K</td>
    <td style="white-space: nowrap; text-align: right">1.44x</td>
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
    <td style="white-space: nowrap">delete 100 by pk</td>
    <td style="white-space: nowrap">0.96 KB</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">delete_by_filter</td>
    <td style="white-space: nowrap">1.31 KB</td>
    <td>1.37x</td>
  </tr>
</table>