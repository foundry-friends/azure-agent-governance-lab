// 未検証・Run 2で確定。APIバージョン・必須propertiesは要確認。未コンパイル。
// VNet/subnet/PE/DNSは公式15の担当。ここは不足するFirewall BasicとUDR。
targetScope = 'resourceGroup'
param location string
param prefix string
param firewallProperties object = {}
param routeTableProperties object = {}
resource firewall 'Microsoft.Network/azureFirewalls@2024-05-01' = {
  name: '${prefix}-firewall'
  location: location
  // BasicのSKU・管理subnet・IP構成・FQDN許可・DNSはRun 2で確定。
  properties: firewallProperties
}
resource routes 'Microsoft.Network/routeTables@2024-05-01' = {
  name: '${prefix}-routes'
  location: location
  // nextHopと関連付け先を推測しない。
  properties: routeTableProperties
}
output firewallResourceId string = firewall.id
output routeTableResourceId string = routes.id
