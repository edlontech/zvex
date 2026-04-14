Benchmark

Benchmark run from 2026-04-14 14:38:00.732891Z UTC

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



__Input: 1 key__

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
    <td style="white-space: nowrap">fetch</td>
    <td style="white-space: nowrap; text-align: right">9.60 K</td>
    <td style="white-space: nowrap; text-align: right">104.20 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;8.03%</td>
    <td style="white-space: nowrap; text-align: right">102.17 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">126.65 &micro;s</td>
  </tr>

</table>


Run Time Comparison

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">IPS</th>
    <th style="text-align: right">Slower</th>
  <tr>
    <td style="white-space: nowrap">fetch</td>
    <td style="white-space: nowrap;text-align: right">9.60 K</td>
    <td>&nbsp;</td>
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
    <td style="white-space: nowrap">fetch</td>
    <td style="white-space: nowrap">992 B</td>
    <td>&nbsp;</td>
  </tr>
</table>



__Input: 10 keys__

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
    <td style="white-space: nowrap">fetch</td>
    <td style="white-space: nowrap; text-align: right">1.06 K</td>
    <td style="white-space: nowrap; text-align: right">943.66 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;4.85%</td>
    <td style="white-space: nowrap; text-align: right">929.38 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">1092.38 &micro;s</td>
  </tr>

</table>


Run Time Comparison

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">IPS</th>
    <th style="text-align: right">Slower</th>
  <tr>
    <td style="white-space: nowrap">fetch</td>
    <td style="white-space: nowrap;text-align: right">1.06 K</td>
    <td>&nbsp;</td>
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
    <td style="white-space: nowrap">fetch</td>
    <td style="white-space: nowrap">5.02 KB</td>
    <td>&nbsp;</td>
  </tr>
</table>



__Input: 100 keys__

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
    <td style="white-space: nowrap">fetch</td>
    <td style="white-space: nowrap; text-align: right">108.41</td>
    <td style="white-space: nowrap; text-align: right">9.22 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;1.71%</td>
    <td style="white-space: nowrap; text-align: right">9.20 ms</td>
    <td style="white-space: nowrap; text-align: right">9.66 ms</td>
  </tr>

</table>


Run Time Comparison

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">IPS</th>
    <th style="text-align: right">Slower</th>
  <tr>
    <td style="white-space: nowrap">fetch</td>
    <td style="white-space: nowrap;text-align: right">108.41</td>
    <td>&nbsp;</td>
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
    <td style="white-space: nowrap">fetch</td>
    <td style="white-space: nowrap">39.48 KB</td>
    <td>&nbsp;</td>
  </tr>
</table>