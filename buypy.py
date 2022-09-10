"""
BuyPy

A command-line backoffice application. This is an interactive 
shell application

(c)  Duarte Ferreira & Milton Cruz, 10/09/2022
"""

import sys
from subprocess import run
from getpass import getpass
import time
import os

import db

'''
    Login com:
    username: pedro@mail.com
    pw: 123abC!
'''
def main():
    user_info = exec_login()
    
    while True:
        cls()
        print(f"\nBem vindo {user_info['firstname']}\n")
        print("U - Menu 'Utilizador'")
        print("P - Menu 'Produto'")
        print("B - Menu 'Backup'")
        print("S - Sair do BackOffice")
        print("L - Logout do BackOffice")

        print()
        option = input(">> ")
        
        if option.lower() == 'u':
            while True:
                os.system('cls')        # Limpar a consola
                print("Menu UTILIZADOR")
                print("1 - Pesquisar utilizador")
                print("2 - Listar detalhes de utilizadores")
                print("3 - Listar utilizadores com contas bloqueadas")
                print("0 - Voltar\n")

                suboption = input(">> ")
                if suboption == '1':
                    print("- Pesquisar Utilizador -")
                    ppesquisar = input("ID ou username: ")
                    os.system('cls')
                    db.PesquisarUser(ppesquisar)
                    input("Enter any key to continue")
                    break
                elif suboption == '2':
                    print("- Detalhes de Utilizadores -")
                    ID = input("ID: ")
                    os.system('cls')
                    db.ListTudo(ID)
                    input("Enter any key to continue")
                    break
                elif suboption == '3':
                    os.system('cls')
                    print("- Utilizadores Bloqueados -")
                    db.ListBloqueados()
                    input("Enter any key to continue")
                    break
                elif suboption =='0':
                    os.system('cls')
                    break
                else:
                    os.system('cls')
                    print(f"Opção <{suboption}> inválida para 'UTILIZADOR'.")
                    time.sleep(1.5)
        elif option.lower() == 'p':
            while True:
                os.system('cls')
                print("Menu PRODUTO")
                print("1 - Listagem de produtos")
                print("2 - Adicionar produto")
                print("3 - (extra)")
                print("0 - Voltar")
                suboption = input(">> ")
                if suboption == '1':
                    intervalo_precos=[]
                    intervalo_quant=[]
                    os.system('cls')
                    print("Listagem de Produtos")
                    tipo = input("Tipo: ")
                    qwe = input("Preço mínimo: ")
                    if qwe=="":
                        intervalo_precos.append(0)
                    else:
                        intervalo_precos.append(int(qwe))
                    qwe = input("Preço máximo: ")
                    if qwe=="":
                        intervalo_precos.append(99999999.99)
                    else:
                        intervalo_precos.append(int(qwe))
                    qwe = input("Quantidade mínima: ")
                    if qwe=="":
                        intervalo_quant.append(0)
                    else:
                        intervalo_quant.append(int(qwe))
                    qwe = input("Quantidade máxima: ")
                    if qwe=="":
                        intervalo_quant.append(sys.maxsize*2+1)
                    else:
                        intervalo_quant.append(int(qwe))
                    if intervalo_precos[0]==0 and intervalo_precos[1]==99999999.99:
                        intervalo_precos=None
                    if intervalo_quant[0]==0 and intervalo_quant[1]==sys.maxsize*2+1:
                        intervalo_quant=None
                    if tipo=="":
                        tipo=None
                    os.system('cls')
                    db.ListagemProdutos(tipo,intervalo_quant,intervalo_precos)
                    input("Enter any key to continue")
                    break
                elif suboption=='2':
                    os.system('cls')
                    print("Adicionar Produto")
                    tipo = input("Tipo: ")
                    ID = input("ID produto: ")
                    quant = input("Quantidade: ")
                    preco = input("Preço: ")
                    score = input("Classificação: ")
                    vat = input("vat(%): ")
                    image = input("Path imagem: ")
                    reason = input("Recomendação: ")
                    # Default values...
                    if vat=='':
                        vat=1.0
                    if reason=='':
                        reason=None
                    db.AdicionarProduto(ID,tipo,quant,preco,score,vat,image,1,reason)
                    time.sleep(1)
                    break
                elif suboption=='0':
                    os.system('cls')
                    break
                else:
                    os.system('cls')
                    print(f"Opção <{suboption}> inválida para 'PRODUTO'.")
                    time.sleep(1.5)
        elif option.lower() == 's':
            print("O BackOffice vai terminar")
            time.sleep(1.5)
            sys.exit(0)
        elif option.lower() == 'b':
            db.ExecBackup()
            print("Backup guardado como buypy_backup")
            time.sleep(1.5)
        else:
            print(f"Opção <{option}> inválida ")
            time.sleep(1.5)
#:

def exec_login():
    """
    Asks for user login info and then tries to authenticate the user in 
    the DB.
    Stores user data the data in the local config file 'config.ini'.
    """
    while True:
        username = input("Username      : ")
        passwd = getpass("Palavra-passe : ")
        user_info = db.login(username, passwd)
        if user_info:
            break
        print("Invalid authentication")
        print()
    return user_info
#:

def cls():
    # pylint: disable=subprocess-run-check
    if sys.platform in ('linux', 'darwin', 'freebsd'):
        run(['clear'])
    elif sys.platform == 'win32':
        run(['cls'], shell=True)
#:
        

if __name__ == '__main__':
    main()
#:
