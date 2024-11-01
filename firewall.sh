#!/bin/bash

local(){ # Função para configurar regras de firewall para tráfego local

    # Libera tráfego com o servidor Samba AD DC
    iptables -t filter -A INPUT -i bond0 -s 10.10.10.5 -j ACCEPT
    iptables -t filter -A OUTPUT -o bond0 -d 10.10.10.5 -j ACCEPT

    # Libera acesso SSH remoto externo
    iptables -t filter -A INPUT -i enp0s3 -p tcp --dport 22 -j ACCEPT
    iptables -t filter -A OUTPUT -o enp0s3 -p tcp --sport 22 -j ACCEPT

    # Libera acesso SSH do firewall para servidores da infraestrutura
    iptables -t filter -A INPUT -i bond0 -p tcp --sport 22 -s 10.10.10.0/24 -j ACCEPT
    iptables -t filter -A OUTPUT -o bond0 -p tcp --dport 22 -d 10.10.10.0/24 -j ACCEPT

    # Libera portas 443, 80, 53 e 123 para conexões do servidor firewall
    iptables -t filter -A INPUT -i enp0s3 -p tcp -m multiport --sports 80,443 -j ACCEPT
    iptables -t filter -A INPUT -i enp0s3 -p udp -m multiport --sports 53,123 -j ACCEPT
    iptables -t filter -A OUTPUT -o enp0s3 -p tcp -m multiport --dports 80,443 -j ACCEPT
    iptables -t filter -A OUTPUT -o enp0s3 -p udp -m multiport --dports 53,123 -j ACCEPT

    # Libera conexões ICMP (ping)
    iptables -t filter -A OUTPUT -o enp0s3 -p icmp --icmp-type 8 -d 0/0 -j ACCEPT
    iptables -t filter -A INPUT -i enp0s3 -p icmp --icmp-type 0 -s 0/0 -j ACCEPT

    # Libera tráfego na interface loopback
    iptables -t filter -A INPUT -i lo -j ACCEPT
    iptables -t filter -A OUTPUT -o lo -j ACCEPT

    # Libera tráfego para SSH e Proxy Squid
    iptables -t filter -A INPUT -i bond0 -p tcp -m multiport --dports 22,3128 -s 10.10.10.0/24 -j ACCEPT
    iptables -t filter -A OUTPUT -o bond0 -p tcp -m multiport --sports 22,3128 -d 10.10.10.0/24 -j ACCEPT
}

forwarding(){ # Função para configurar regras de firewall para tráfego de encaminhamento (forwarding)

    # Libera portas 443, 80, 53 e 123 para tráfego da rede LAN 10.10.10.0/24
    iptables -t filter -A FORWARD -i enp0s3 -p tcp -m multiport --sports 80,443 -d 10.10.10.0/24 -j ACCEPT
    iptables -t filter -A FORWARD -i enp0s3 -p udp -m multiport --sports 53,123 -d 10.10.10.0/24 -j ACCEPT
    iptables -t filter -A FORWARD -i enp0s3 -p tcp --sport 53 -d 10.10.10.0/24 -j ACCEPT
    iptables -t filter -A FORWARD -i bond0 -p tcp -m multiport --dports 80,443 -s 10.10.10.0/24 -j ACCEPT
    iptables -t filter -A FORWARD -i bond0 -p udp -m multiport --dports 53,123 -s 10.10.10.0/24 -j ACCEPT
    iptables -t filter -A FORWARD -i bond0 -p tcp --dport 53 -s 10.10.10.0/24 -j ACCEPT

    # Libera conexões ICMP (ping) para LAN 10.10.10.0/24
    iptables -t filter -A FORWARD -o enp0s3 -p icmp --icmp-type 8 -d 0/0 -s 10.10.10.0/24 -j ACCEPT
    iptables -t filter -A FORWARD -i enp0s3 -p icmp --icmp-type 0 -s 0/0 -d 10.10.10.0/24 -j ACCEPT
}

internet(){ # Função para habilitar o compartilhamento de internet (NAT)

    sysctl -w net.ipv4.ip_forward=1 # Habilita o encaminhamento de pacotes IPv4
    iptables -t nat -A POSTROUTING -s 10.10.10.0/24 -o enp0s3 -j MASQUERADE # Configura NAT para a LAN 10.10.10.0/24
}

default(){ # Função para definir política padrão de DROP (bloqueio)

    iptables -t filter -P INPUT DROP # Bloqueia todas as conexões de entrada
    iptables -t filter -P OUTPUT DROP # Bloqueia todas as conexões de saída
    iptables -t filter -P FORWARD DROP # Bloqueia todas as conexões de encaminhamento
}

iniciar(){ # Função para iniciar todas as configurações

    local         # Chama a função local
    forwarding    # Chama a função forwarding
    default       # Chama a função default
    internet      # Chama a função internet
}

parar(){ # Função para interromper o firewall e limpar regras

    iptables -t filter -P INPUT ACCEPT # Permite todas as conexões de entrada
    iptables -t filter -P OUTPUT ACCEPT # Permite todas as conexões de saída
    iptables -t filter -P FORWARD ACCEPT # Permite todas as conexões de encaminhamento
    iptables -t filter -F # Limpa todas as regras do firewall
}

# Condicional para executar funções com base no argumento passado ao script
case $1 in
    start|START|Start)iniciar;; # Inicia o firewall
    stop|STOP|Stop)parar;;      # Para o firewall
    restart|RESTART|Restart)parar;iniciar;; # Reinicia o firewall
    listar)iptables -t filter -nvL;; # Lista as regras atuais
    *)echo "Execute o script com os parâmetros start ou stop ou restart";; # Exibe mensagem de uso
esac
