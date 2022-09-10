"""
This module defines functions and classes related to DB access.

(c)  Duarte Ferreira & Milton Cruz, 10/09/2022
"""

from hashlib import sha256 as default_hashalgo
#from types import NoneType
from mysql.connector import connect, Error as MySQLError
import datetime
import pandas as pd
import isbnlib
import time
'''
    Utilizadores disponíveis:
    -
    user: CLIENTE
    password: 123
    Permissões apenas de visualização (utilizador cliente)
    -
    user: operator
    password: abc
    Todas as permissões (utilizador admin/operador)
'''
DB_CONN_PARAMS = {
    'host': '127.0.0.1',
    'user': 'operator',
    'password': 'abc',
    'database': 'buypy'
}

database = DB_CONN_PARAMS["database"]
today = datetime.datetime.now()

def login(username: str, passwd: str) -> dict:
    hash_obj = default_hashalgo()
    hash_obj.update(passwd.encode())
    hash_passwd = hash_obj.hexdigest()
    with connect(**DB_CONN_PARAMS) as connection:
        with connection.cursor() as cursor:
            cursor.callproc('AuthenticateOperator', [username, hash_passwd])
            user_info = next(cursor.stored_results())
            if user_info.rowcount != 1:
                return None
            user_row = user_info.fetchall()[0]
            return dict(zip(user_info.column_names, user_row))
#:

def ProdutoPorTipo(tipo):
    if tipo!=None:
        tipo = "'"+tipo+"'"
    with connect(**DB_CONN_PARAMS) as connection:
        with connection.cursor() as cur:
            cur.callproc('ProdutoPorTipo', [tipo])
            #time.sleep(1.5)
            df = pd.DataFrame(columns=['ID', 'Preço', 'Score', 'Recomendação', 'Ativo', 'Imagem'])
            for result in cur.stored_results():
                result = pd.DataFrame(result, columns=['ID', 'Preço', 'Score', 'Recomendação', 'Ativo', 'Imagem'])
                df = df.append(result)
            print(df)
                

def PesquisarUser(idORusername):
    with connect(**DB_CONN_PARAMS) as connection:
        with connection.cursor() as cur:
            cur.execute("SELECT id,firstname,surname,city,zip_code,birthdate,email FROM "+database+".client WHERE id=%s OR email=%s", [idORusername,idORusername])
            # Dataframe para ter prints mais elegantes facilmente
            df = pd.DataFrame(cur.fetchall(),columns=['ID', 'Nome', 'Apelido', 'Cidade', 'Codigo Postal', 'Data Nasc.', 'Email'])
            print(df)
            # Check if is_active
            cur.execute("SELECT is_active FROM "+database+".client WHERE id=%s OR email=%s", [idORusername,idORusername])
            is_active = cur.fetchone()[0]
            if (is_active==1): # [0][0] porque fetchall devolve uma lista de tuples!
                active = "active"
                b = "block"
            else:
                active = "blocked"
                b = "unblock"
            print(f"{df['Email'][0]} with user ID {df['ID'][0]} is {active}. Do you wish to {b}?")
            while True:
                yn = input(">[Y/N]: ")
                # if N go back
                # if Y block/unblock
                if (yn.upper() == 'Y'):
                    # if is_active==0: 1-0=1
                    # if is_active==1: 1-1=0
                    idtoset=int(df['ID'][0])
                    try:
                        cur.execute("UPDATE "+database+".client SET is_active=%s WHERE id=%s", [1-is_active,idtoset])
                        connection.commit()
                    except MySQLError:
                        print("Update failed")
                    break
                elif (yn.upper() == 'N'):
                    break

def ListagemProdutos(tipo=None,quant=None,preco=None):
    with connect(**DB_CONN_PARAMS) as connection:
        with connection.cursor() as cur:
            # NO PARAMETERS; JUST PRINT EVERYTHING
            if (quant==None and preco==None):
                ProdutoPorTipo(tipo)
            #########################
            # NO SPECIFIED QUANTITY #
            #########################
            elif(quant==None):
                # For each product we need --quantity and price from PRODUCT
                # --model and brand OR --title from ELECTRONIC/BOOK
                cur.execute("SELECT quantity,price FROM "+database+".product WHERE price BETWEEN %s AND %s", [preco[0],preco[1]])
                all_prod = cur.fetchall()
                cur.execute("SELECT id FROM "+database+".product WHERE price BETWEEN %s AND %s", [preco[0],preco[1]])
                ids_for = cur.fetchall()
                # all_prod should have all quantities, prices
                # now we need to get from type for each quantity,price
                ProdListPrint(cur,all_prod,ids_for)
            ######################
            # NO SPECIFIED PRICE #
            ######################
            elif(preco==None):
                cur.execute("SELECT quantity,price FROM "+database+".product WHERE quantity BETWEEN %s AND %s", [quant[0],quant[1]])
                all_prod = cur.fetchall()
                # Search for id in Electronic and in Book so we can know the type
                cur.execute("SELECT id FROM "+database+".product WHERE quantity BETWEEN %s AND %s", [quant[0],quant[1]])
                ids_for = cur.fetchall()
                ProdListPrint(cur,all_prod,ids_for)
            else:
            ############################
            # ALL PARAMS ARE SPECIFIED #
            ############################
                cur.execute("SELECT quantity,price FROM "+database+".product WHERE (quantity BETWEEN %s AND %s) AND (price BETWEEN %s AND %s)", [quant[0],quant[1],preco[0],preco[1]])
                all_prod = cur.fetchall()
                cur.execute("SELECT id FROM "+database+".product WHERE (quantity BETWEEN %s AND %s) AND (price BETWEEN %s AND %s)", [quant[0],quant[1],preco[0],preco[1]])
                ids_for = cur.fetchall()
                ProdListPrint(cur,all_prod,ids_for)


def ProdListPrint(cursor,all_products,ids_for):
    '''
        Uses cursor to select products from electronic and book tables.
        all_products should have quantity and price from product table.
        ids_for should have all IDs we're selecting from electronic and book tables.
        This function is supposed to help printing for all kinds of searches
        we might want to implement
    '''
    elec_part=list(all_products)
    book_part=list(all_products)
    df_book = pd.DataFrame(columns=["Quantity","Price","Title","Type"])
    df_elec = pd.DataFrame(columns=["Quantity","Price","Brand","Model","Type"])
    # Search for id in Electronic and in Book so we can know the type
    #cur.execute("SELECT id FROM "+database+".product WHERE price BETWEEN %s AND %s", [preco[0],preco[1]])
    
    i=0
    for idFK in ids_for: # i as in index
        cursor.execute("SELECT title FROM "+database+".book WHERE product_id=%s", idFK)
        #print(cur.fetchone())
        titlu=cursor.fetchone()
        if (titlu!=None):
            book_part[i]= book_part[i]+titlu+("Book",)
            # Put this into dataframe
            df_book.loc[len(df_book)] = book_part[i]
            i+=1
        else:
            # Remove from list or - just don't add to dataframe...
            print()
    for idFK in ids_for:
        cursor.execute("SELECT brand,model FROM "+database+".electronic WHERE product_id=%s", idFK)
        bmodel=cursor.fetchone()
        if (bmodel!=None):
            elec_part[i]= elec_part[i]+bmodel+("Electronic",)
            # Put this into dataframe
            df_elec.loc[len(df_elec)] = elec_part[i]
            i+=1
    # Now join both dataframes and just print
    final = df_book.merge(df_elec,how='outer')
    print(final)

def AdicionarProduto(charID,tipo,quant,preco,score,vat=1.0,product_image="",active=1,reason=None):
    '''
        Permite adicionar produto, mas apenas se o utilizador tiver permissões.
        Recolhe todas as informações necessárias e preenche as tabelas Product e book ou electronic
    '''
    with connect(**DB_CONN_PARAMS) as connection:
        with connection.cursor() as cur:
            cur.execute("INSERT INTO "+database+".product VALUES(%s,%s,%s,%s,%s,%s,%s,%s)",[charID,quant,preco,vat,score,product_image,active,reason])
            connection.commit()
            ###########################################
            # NEW PRODUCT IS AN ELECTRONIC CONSUMABLE #
            ###########################################
            if (tipo.lower()=='electronic'):
                print("Inserting Electronic Product")
                serial_num = input("Serial number: ")
                brand = input("Brand: ")
                model = input("Model: ")
                spec_tec = input("Technical specificities: ")
                tttype = input("Type: ")
                cur.execute("INSERT INTO "+database+".electronic VALUES(%s,%s,%s,%s,%s,%s)",[charID,serial_num,brand,model,spec_tec,tttype])
                connection.commit()
            #########################
            # NEW PRODUCT IS A BOOK #
            #########################
            elif (tipo.lower()=='book'):
                print("Inserting Book Product")
                while True:
                    isbn = input("isbn13: ")
                    if isbnlib.is_isbn13(isbn):
                        break
                    else:
                        print("Invalid isbn13.\n")
                title = input("Title: ")
                genre = input("Genre: ")
                publisher = input("Publisher: ")
                pub_date = input("Publication date (yyyy-mm-dd): ")
                cur.execute("INSERT INTO "+database+".book(product_id, isbn13, title, genre, publisher, publication_date) VALUES(%s,%s,%s,%s,%s,%s)",[charID,isbn,title,genre,publisher,pub_date])
                connection.commit()         # So that the insert actually works
            else:
                print(f"{tipo} unknown type. Please insert \'electronic\' or \'book\'")


########################################################################
########                        EXTRAS                          ########
########################################################################
def ListTudo(id):
    with connect(**DB_CONN_PARAMS) as connection:
        with connection.cursor() as cur:
            cur.execute("SELECT id,firstname,surname,email,address,city,zip_code,country,phone_number,birthdate,last_login,is_active FROM "+database+".client WHERE id=%s", [id])
            # Dataframe para ter prints mais elegantes facilmente
            df = pd.DataFrame(cur.fetchall(),columns=['ID', 'Nome', 'Apelido', 'Email', 'Morada', 'Cidade', 'Codigo Postal', 'País',  'Telefone', 'Data Nasc.', 'Último Login', 'Ativo'])
            if df.empty:
                print(f"No user with ID={id}")
            else:
                print(df)


def ListBloqueados():
    with connect(**DB_CONN_PARAMS) as connection:
        with connection.cursor() as cur:
            cur.execute("SELECT id,firstname,surname,city,zip_code,birthdate,email FROM "+database+".client WHERE is_active=%s", [0])
            # Dataframe para ter prints mais elegantes facilmente
            df = pd.DataFrame(cur.fetchall(),columns=['ID', 'Nome', 'Apelido', 'Cidade', 'Codigo Postal', 'Data Nasc.', 'Email'])
            if df.empty:
                print("No blocked users.")
            else:
                print(df)

def ExecBackup():
    with connect(**DB_CONN_PARAMS) as connection:
        with connection.cursor() as cur:
            cur.execute("SHOW TABLES;")
            table_names =[]
            for record in cur.fetchall():
                table_names.append(record[0])
            backup_name = database+'_backup'
            try:
                cur.execute(f"CREATE DATABASE {backup_name}")
            except:
                pass
            cur.execute(f"USE {backup_name}")
            for table_name in table_names:
                cur.execute("DROP TABLE IF EXISTS `"+table_name+"`")
                cur.execute("CREATE TABLE `"+table_name+"` SELECT * FROM "+f"{database}.`{table_name}`") # Colocar `` porque temos a tabela order e order também é uma instrução mySQL!!
