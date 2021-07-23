[winclient]
%{ for host, ip in hosts ~}
${host} ansible_host=${ip}
%{ endfor ~}
