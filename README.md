# BitKeep Exchange

## About

The library contains a smart contract for EVM-based blockchains (Ethereum, BNB Chain, etc.), which serves as a critical
part of the BitKeep Exchange protocol.

This contract allows users to buy batch from different marketplace, with optional swapping actions ahead of buying.
Meanwhile, it provides users with the best swap price and saves gas fees.

## Deploy

The protocol is deployed by CREATE2 Factory with the same address on each EVM. The address is as follows

<table>
<tr>
<th>Network</th>
<th>BKExchange</th>
</tr>

<tr><td>Ethereum</td><td rowspan="14">

<tr><td>BNB Chain</td></tr>
<tr><td>Polygon</td></tr>
<tr><td>Optimism</td></tr>
<tr><td>Arbitrum</td></tr>
</table>

## Audit

