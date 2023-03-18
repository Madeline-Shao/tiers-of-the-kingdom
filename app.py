"""
Application code for a tier list maker, using MySQL with Python for the
tier list database.
"""
import sys  # to print error messages to sys.stderr
import mysql.connector
# To get error codes from the connector, useful for user-friendly
# error-handling
import mysql.connector.errorcode as errorcode
from enum import Enum
from collections import defaultdict

# Name: Madeline Shao
# Email: mshao@caltech.edu

# Debugging flag to print errors when debugging that shouldn't be visible
# to an actual client.
# Set to False when done testing.
DEBUG = False

class Colors(Enum):
    '''
    Enum for AINSI color codes to color print to terminal.
    '''
    END = '\033[0m'
    RED = '\u001b[31;1m'
    YELLOW = '\u001b[33;1m'
    GREEN = '\u001b[32;1m'
    BLUE = '\u001b[34;1m'
    MAGENTA = '\u001b[35m'
    CYAN = '\u001b[36m'
    GRAY = '\u001b[30;1m'
    WHITE = '\u001b[37;1m'
    ERROR = '\u001b[31m' # light red
    SUCCESS = '\u001b[32m' # light green
    WARNING = '\u001b[33m' # light yellow
    BOLD = '\u001b[1m'

# connection global variable
conn = None

# ----------------------------------------------------------------------
# Print Utility Functions
# ----------------------------------------------------------------------

def print_success(msg):
    '''
    Print message in light green.
    '''
    print(f"{Colors.SUCCESS.value}{msg}{Colors.END.value}")

def print_err(msg):
    '''
    Print message in light red.
    '''
    print(f"{Colors.ERROR.value}{msg}{Colors.END.value}")

def print_bold(msg):
    '''
    Print message in bold.
    '''
    print(f"{Colors.BOLD.value}{msg}{Colors.END.value}")

def print_warning(msg):
    '''
    Print message in light yellow.
    '''
    print(f"{Colors.WARNING.value}{msg}{Colors.END.value}")

# ----------------------------------------------------------------------
# SQL Utility Functions
# ----------------------------------------------------------------------
def get_conn(admin=False):
    """"
    Returns a connected MySQL connector instance, if connection is successful.
    If unsuccessful, exits.
    """
    try:
        user = 'appclient'
        pw = 'clients'
        if admin:
            user = 'appadmin'
            pw = 'admins'
        global conn
        conn = mysql.connector.connect(
          host='localhost',
          user='appadmin',
          # Find port in MAMP or MySQL Workbench GUI or with
          # SHOW VARIABLES WHERE variable_name LIKE 'port';
          port='3306',
          password='admins',
          database='tierlistdb'
        )
        return conn
    except mysql.connector.Error as err:
        # Remember that this is specific to _database_ users, not
        # application users. So is probably irrelevant to a client in your
        # simulated program. Their user information would be in a users table
        # specific to your database.
        if err.errno == errorcode.ER_ACCESS_DENIED_ERROR and DEBUG:
            sys.stderr('Incorrect username or password when connecting to DB.')
        elif err.errno == errorcode.ER_BAD_DB_ERROR and DEBUG:
            sys.stderr('Database does not exist.')
        elif DEBUG:
            sys.stderr(err)
        else:
            sys.stderr('An error occurred, please contact the administrator.')
        sys.exit(1)

# ----------------------------------------------------------------------
# Functions for Command-Line Options/Query Execution
# ----------------------------------------------------------------------
def entry_exists(table, column1, value1, column2=None, value2=None,
                column3=None, value3=None):
    '''
    General helper function to check if the given table has record with an
    entry of value1 in column1.
    If column2, value2, column3, value3 are given, also checks that the record
    has those values in their respective columns.
    Returns true if such a record exists, returns false if it does not exist.
    If the connection encounters an error, returns None.
    '''
    try:
        cursor = conn.cursor()
        if isinstance(value1, str):
            sql = 'SELECT %s FROM %s WHERE %s=\'%s\'' % (column1, table,
                                                        column1, value1)
        elif isinstance(value1, int):
            sql = 'SELECT %s FROM %s WHERE %s=%d' % (column1, table,
                                                     column1, value1)
        else:
            assert False

        if column2 is not None and value2 is not None:
            if isinstance(value2, str):
                sql = sql + ' AND %s=\'%s\'' % (column2, value2)
            elif isinstance(value2, int):
                sql = sql + ' AND %s=%d' % (column2, value2)
            else:
                assert False

        if column3 is not None and value3 is not None:
            if isinstance(value3, str):
                sql = sql + ' AND %s=\'%s\'' % (column3, value3)
            elif isinstance(value3, int):
                sql = sql + ' AND %s=%d' % (column3, value3)
            else:
                assert False

        sql = sql + ';'
        cursor.execute(sql)
        rows = cursor.fetchall()
        if not rows:
            return False
        return True
    except mysql.connector.Error as err:
        if DEBUG:
            print(err)
        else:
            sys.stderr('An error occurred when querying the database.')

def username_tierlist_exists(username, tierlist_name):
    sql = 'SELECT user_owns_tierlist(\'%s\', \'%s\')' % (username,
                                                         tierlist_name)
    try:
        cursor = conn.cursor()
        cursor.execute(sql)
        result = cursor.fetchone()
    except mysql.connector.Error as err:
        if DEBUG:
            sys.stderr(err)
            sys.exit(1)
        else:
            sys.stderr('An error occurred when validating this username-tierlist pair.')
            return

    if result[0] == 1:
        return True
    else:
        return False

def show_games():
    """
    Prompts the user to choose a column to filter by and/or a column to sort by,
    then shows a list of games with their id, name, developer,
    publisher, release date, number of sales, and platform, limited to
    the top 30 entries.
    By default, no filters are applied and results are sorted by date in
    ascending order.
    If the input filter column, sort column, or sort direction are invalid,
    prints an error message and returns.
    """
    global conn
    ans = input('Do you want to filter the results? ')
    filter_col = None
    filter_val = None
    # columns in the table video_game
    game_cols = ("game_id", "game_name", "developer", "publisher",
                 "release_date", "sales", "platform")
    if ans and ans.lower()[0] == 'y':
        filter_col = input('Enter a column to filter by: ')
        filter_val = input('Enter the value the column should be equal to: ')
    if not filter_col or (filter_col == "" and filter_val == ""):
        game_filter = ""
    else:
        if filter_col.lower() not in game_cols:
            print_err(f"Unable to filter: Column '{filter_col}' doesn't exist")
            return
        else:
            game_filter = "WHERE %s=\'%s\' " % (filter_col, filter_val)

    ans = input('Do you want to sort the results? ')
    sort_col = None
    sort_dir = None
    if ans and ans.lower()[0] == 'y':
        sort_col = input('Enter a column to sort by (default release_date): ')
        sort_dir = input('What direction? (\'asc\' (default) or \'desc\'): ')
    if not sort_col:
        sort_col = "release_date"
    if not sort_dir:
        sort_dir = "asc"
    else:
        if sort_col == "":
            sort_col = "release_date" # default
        elif sort_col.lower() not in game_cols:
            print_err(f'Unable to sort: Column \'{sort_col}\' does not exist')
            return
        if sort_dir == "":
            sort_dir = "asc" # default
        elif sort_dir.lower() not in ("asc", "desc"):
            print_err(f'Unable to sort: Direction \'{sort_dir}\' is invalid')
            return
    game_sort = "ORDER BY %s %s" % (sort_col, sort_dir)

    sql = """
              SELECT *
              FROM video_game
              %s
              %s LIMIT 30;
              """ % (game_filter, game_sort)
                # escape parameters for secure execution
    try:
        cursor = conn.cursor()
        cursor.execute(sql)
        rows = cursor.fetchall()
    except mysql.connector.Error as err:
        if DEBUG:
            sys.stderr(err)
            sys.exit(1)
        else:
            sys.stderr('An error occurred when searching for video games.')
            return

    if not rows:
        print_warning('No results found.')
    else:
        if game_filter != "":
            print(f'Top 30 Nintendo games where {filter_col} = \'{filter_val}\', sorted by {sort_col} {sort_dir}:')
        else:
            print(f'Top 30 Nintendo games in database, sorted by {sort_col} {sort_dir}')
        # 40
        print_bold('ID  | game name                                | developer            | publisher     | release_date | sales    | platform')
        print_bold('--------------------------------------------------------------------------------------------------------------------------')
        for row in rows:
            (game_id, name, developer, publisher,
             release_date, sales, platform) = row
            print(f'{str(game_id).ljust(3)} | {name.ljust(40)} | {developer.ljust(20)} | {publisher.ljust(13)} | {str(release_date).ljust(12)} | {str(sales).ljust(8)} | {platform}')

def get_color_code(color):
    '''
    Given an input string, gets the color code for that color. If the input
    is not a valid color, returns an empty string.
    '''
    color_code = ""
    available_colors = [member.name for member in Colors]
    if color.upper() in available_colors:
        color_code = Colors[color.upper()].value
    return color_code

def get_sorted_tiers():
    '''
    Returns all the rows from the table tier, sorted by tier_rank ascending.
    '''
    global conn
    try:
        cursor = conn.cursor()
        cursor.execute('SELECT * FROM tier ORDER BY tier_rank;')
        rows = cursor.fetchall()
        return rows
    except mysql.connector.Error as err:
        if DEBUG:
            print(err)
        else:
            sys.stderr('An error occurred when fetching the tiers.')

def show_tiers():
    try:
        rows = get_sorted_tiers() # tiers sorted by rank
        if not rows:
            print_warning('No results found.')
            return
        print_bold('ID | rank | name')
        print_bold('----------------')
        for row in rows:
            color_code = get_color_code(row[3])
            # if color doesn't exist, uses terminal default
            print(f'{color_code}{str(row[0]).ljust(2)} | {str(row[1]).ljust(4)} | {row[2].ljust(4)}{Colors.END.value}')
    except mysql.connector.Error as err:
        if DEBUG:
            print(err)
        else:
            sys.stderr('An error occurred when fetching the tiers.')

def show_tierlists():
    '''
    Shows all the tierlists and their owners in the database. Displays
    the username and the tierlist name, sorted by username ascending.
    '''
    global conn
    try:
        cursor = conn.cursor()
        cursor.execute('SELECT * FROM tierlist ORDER BY username;')
        rows = cursor.fetchall()
        if not rows:
            print_warning('No results found.')
            return
        print_bold('username             | date tierlist created | tierlist name')
        print_bold('------------------------------------------------------------')
        for row in rows:
            print(f'{row[0].ljust(20)} | {str(row[2]).ljust(21)} | {row[1]}')
    except mysql.connector.Error as err:
        if DEBUG:
            print(err)
        else:
            sys.stderr('An error occurred when fetching the tiers.')

def print_tierlist(username, tierlist_name):
    '''
    Prints the given tierlist in color.
    '''
    try:
        cursor = conn.cursor()
        cursor.execute('SELECT game_name, tier_rank FROM game_tier JOIN video_game USING(game_id) JOIN tier USING(tier_id) WHERE username=\'%s\' AND tierlist_name = \'%s\' ORDER BY tier_rank;' % (username, tierlist_name))
        rows = cursor.fetchall()
        if not rows:
            print()
            print_warning(f'User {username}\'s tierlist {tierlist_name} is empty.')
            return
    except mysql.connector.Error as err:
        if DEBUG:
            print(err)
        else:
            sys.stderr('An error occurred when fetching the tiers.')
    print()
    # Create a dictionary where the key is the rank and the value is
    # a list of games assigned to that rank
    tier_dict = defaultdict(list)
    for row in rows:
        key = row[1]
        tier_dict[key].append(row[0])

    # get a list of tier tuples sorted by rank
    sorted_tiers = get_sorted_tiers()
    for tier_tuple in sorted_tiers:
        # get the color for the tier
        color_code = get_color_code(tier_tuple[3])
        tier_name = tier_tuple[2]
        # first print the tier name
        result = f'{color_code}{tier_name} | '
        # then print the games, comma separated
        for game in tier_dict[tier_tuple[1]]:
            result = result + f'{game}, '
        if result.endswith(", "):
            result = result[:-2]
        result = result + f'{Colors.END.value}'
        print(result)

def view_tierlist():
    '''
    Prompts user to enter a username and a tierlist to display. If the input
    user does not own the input tierlist or if the tierlist is empty, a message
    is printed accordingly. Otherwise, the tierlist printed, ordered by tier
    rank and each tier is colored accordingly.
    '''
    global conn
    username = input('Enter the username of the user who owns the tierlist: ')
    tierlist_name = input('Enter the name of the tierlist: ')
    # if not entry_exists('tierlist', 'username', username,
    #                     'tierlist_name', tierlist_name):
    if not username_tierlist_exists(username, tierlist_name):
        print_err(f'User {username} does not own a tierlist named {tierlist_name}.')
        return
    print_tierlist(username, tierlist_name)

def view_stats():
    '''
    Prompts the user to filter for a particular game (displays stats for all
    ranked games by default). Shows the game name, average rank, minimum rank,
    and maximum rank for the game(s), ordered by average rank ascending.
    '''
    global conn
    ans = input('Do you want to filter for a particular game? ')
    game_name = None
    if ans and ans.lower()[0] == 'y':
       game_name = input('Enter the name of a game: ')
    if game_name is None:
        game_filter = ""
    else:
        game_filter = "WHERE game_name=\'%s\' " % (game_name,)

    try:
        cursor = conn.cursor()
        sql = 'SELECT game_name, avg_rank, min_rank, max_rank \
FROM game_rank_stats JOIN video_game USING(game_id) %sORDER BY avg_rank ASC;' % (game_filter,)
        cursor.execute(sql)
        rows = cursor.fetchall()
        if not rows:
            print_warning('No results found. Game has not been ranked yet.')
            return
        print_bold('game name                                | avg rank | min rank | max rank')
        print_bold('-------------------------------------------------------------------------')
        for row in rows:
            print(f'{row[0].ljust(40)} | {str(row[1]).ljust(8)} | {str(row[2]).ljust(8)} | {str(row[3]).ljust(8)}')
    except mysql.connector.Error as err:
        if DEBUG:
            print(err)
        else:
            sys.stderr('An error occurred when fetching the tiers.')

def choose_tierlist_for_edit(username, is_admin):
    '''
    Prompts the user to choose the name of a tierlist to edit. If the user
    inputs a tierlist that they do not have, then a message is printed
    accordingly. Otherwise, displays the edit tierlist menu.
    '''
    global conn
    name = input('Enter the name of the tierlist to be edited. You can only edit your tierlists: ')
    # tierlist_exists = entry_exists("tierlist", "tierlist_name",
    #                                name, "username", username)
    # if not tierlist_exists:
    if not username_tierlist_exists(username, name):
        print_err(f'Failed to edit tierlist: User {username} does not own a tierlist named {name}')
        return
    print()
    edit_tierlist_options(username, name, is_admin)

def add_update_game_tier(username, tierlist):
    '''
    Prompts the user enter the id of a game and a tier. If the game or tier id
    is not an integer or is not a valid id, prints a message accordingly.
    Otherwise, assigns the game to the tier of the given tierlist.
    '''
    global conn
    game_id = input(f'Enter the id of the game: ')
    try:
        game_id = int(game_id)
    except ValueError:
        print_err(f'Failed to assign game to a tier: Game id input {game_id} was not a number')
        return
    if not entry_exists("video_game", "game_id", game_id):
        print_err(f'Failed to assign game to a tier: game id {game_id} does not exist')
        return

    tier_id= input(f'Enter the id of the tier: ')
    try:
        tier_id = int(tier_id)
    except ValueError:
        print_err(f'Failed to assign game to a tier: Tier id {tier_id} was not a number')
        return
    if not entry_exists("tier", "tier_id", tier_id):
        print_err(f'Failed to assign game to a tier: tier id {tier_id} does not exist')
        return
    sql = 'CALL sp_update_game_tier(\'%s\', \'%s\', %d, %d);' % (username,
                                                                 tierlist,
                                                                 game_id,
                                                                 tier_id)
    try:
        cursor = conn.cursor()
        cursor.execute(sql)
        conn.commit()
        print_success('Game successfully assigned to tier!')
    except mysql.connector.Error as err:
        if DEBUG:
            print(err)
        else:
            sys.stderr('An error occurred when assigning the game to a tier.')
        return
    print_tierlist(username, tierlist)

def delete_game_tier(username, tierlist):
    '''
    Prompts the user to enter the id of a game. If the game or tier id
    is not an integer or is not a valid id, prints a message accordingly.
    If the game is not in the tierlist, prints a message
    accordingly. Otherwise, deletes the game from the tierlist.
    '''
    global conn
    id = input(f'Enter the id of the game to delete from tierlist {tierlist}: ')
    try:
        id = int(id)
    except ValueError:
        print_err(f'Failed to delete game from tierlist: Game id input {id} was not a number')
        return

    if not entry_exists("game_tier", "game_id", id, "username",
                        username, "tierlist_name", tierlist):
        print_err(f'Failed to delete game: Game id {id} is not in tierlist {tierlist}')
        return

    sql = 'CALL sp_delete_game_tier(\'%s\', \'%s\', %d);' % (username,
                                                             tierlist, id)
    try:
        cursor = conn.cursor()
        cursor.execute(sql)
        conn.commit()
        print_success(f'Game {id} deleted from tierlist {tierlist}!')
    except mysql.connector.Error as err:
        if DEBUG:
            print(err)
        else:
            sys.stderr('An error occurred when deleting the game from the tierlist.')
        return
    print_tierlist(username, tierlist)

def create_tierlist(username):
    '''
    Prompts the user for the name of the new tierlist. If the user already
    has a tierlist with that name, an error message is printed. Otherwise,
    creates the tierlist for the user.
    '''
    global conn
    name = input('Enter the name of the new tierlist: ')
    # tierlist_exists = entry_exists("tierlist", "tierlist_name",
    #                                name, "username", username)
    # if tierlist_exists is None or tierlist_exists:
    if username_tierlist_exists(username, name):
        print_err(f'Failed to create tierlist: User {username} already has a tierlist named {name}')
        return
    sql = 'CALL sp_insert_tierlist(\'%s\', \'%s\');' % (username, name)
    try:
        cursor = conn.cursor()
        cursor.execute(sql)
        conn.commit()
        print_success('Tierlist added!')
    except mysql.connector.Error as err:
        if DEBUG:
            print(err)
        else:
            sys.stderr('An error occurred when adding the tierlist.')
        return

def delete_tierlist(username):
    '''
    Prompts the user for the name of a tierlist to delete. If the user
    does not own that tierlist, an error message is printed. Otherwise,
    the tierlist is deleted.
    '''
    global conn
    name = input('Enter the name of the tierlist to be deleted. You can only delete your tierlists: ')
    # tierlist_exists = entry_exists("tierlist", "tierlist_name",
    #                                name, "username", username)
    # if not tierlist_exists:
    if not username_tierlist_exists(username, name):
        print_err(f'Failed to delete tierlist: User {username} does not own a tierlist named {name}')
        return
    sql = 'CALL sp_delete_tierlist(\'%s\', \'%s\');' % (username, name)
    try:
        cursor = conn.cursor()
        cursor.execute(sql)
        print_success('Tierlist deleted!')
    except mysql.connector.Error as err:
        if DEBUG:
            print(err)
        else:
            sys.stderr('An error occurred when deleting the tierlist.')
        return

def add_game():
    '''
    For admins only. Prompts the user to enter the game name, developer,
    publisher, release_date, sales, and platform. If the input sales is not
    a number or the date is not formatted correctly, an error message is
    printed. Otherwise if the input sales is empty,
    sales is set to null. Adds the game to the video_game table and prints
    the id.
    '''
    global conn
    name = input('Enter the name of the new game: ')
    developer = input('Enter the developer: ')
    publisher = input('Enter the publisher: ')
    release_date = input('Enter the release date (YYYY-MM-DD): ')
    sales = input('Enter the number of sales (integer). Press enter if \
there are no sales yet: ')
    if sales == '':
        sales = None
    else:
        try:
            sales = int(sales)
        except ValueError:
            print_err(f'Failed to add game: Sales input {sales} was not a number')
            return
    platform = input('Enter the platform: ')
    if not sales:
        # if sales not given, set it to NULL
        sql = 'CALL sp_insert_video_game(\'%s\', \'%s\', \'%s\', \'%s\', NULL, \
        \'%s\');' % (name, developer, publisher, release_date, platform)
    else:
        sql = 'CALL sp_insert_video_game(\'%s\', \'%s\', \'%s\', \'%s\', %d, \
        \'%s\');' % (name, developer, publisher, release_date, sales, platform)
    try:
        cursor = conn.cursor()
        cursor.execute(sql)
        conn.commit()
        print_success('Game added!')
    except mysql.connector.Error as err:
        if err.errno == errorcode.ER_TRUNCATED_WRONG_VALUE:
            print_err(f'Failed to add game: Date {release_date} was not formatted correctly')
        elif DEBUG:
            print(err)
        else:
            sys.stderr('An error occurred when adding the game.')
        return
    try:
        cursor = conn.cursor()
        cursor.execute('SELECT LAST_INSERT_ID();')
        row = cursor.fetchone()
        print(f'ID of new game: {row[0]}')
    except mysql.connector.Error as err:
        if DEBUG:
            print(err)
        else:
            sys.stderr('An error occurred when adding the game.')

def update_game_sales():
    '''
    For admins only. Prompts the user to enter the id of a game and a new sales
    number. If the game id or sales number is not an integer or the game id is
    not a valid id, prints a message accordingly. Otherwise, updates the sales
    of the game.
    '''
    global conn
    id = input('Enter the id of the existing game (integer): ')
    try:
        id = int(id)
    except ValueError:
        print_err(f'Failed to update game: Game id input {id} was not a number')
        return
    if not entry_exists("video_game", "game_id", id):
        print_err(f'Failed to update game: Game id input {id} does not exist')
        return
    sales = input('Enter the updated number of sales (integer): ')
    if sales == '':
        sales = None
        sql = 'CALL sp_update_video_game_sales(\'%d\', NULL);' % (id)
    else:
        try:
            sales = int(sales)
        except ValueError:
            print_err(f'Failed to update game: Sales input {sales} was not a number')
            return
        sql = 'CALL sp_update_video_game_sales(\'%d\', \'%d\');' % (id, sales)
    try:
        cursor = conn.cursor()
        cursor.execute(sql)
        conn.commit()
        print_success('Sales updated!')
    except mysql.connector.Error as err:
        if DEBUG:
            print(err)
        else:
            sys.stderr('An error occurred when updating the game sales.')

def add_tier():
    '''
    For admins only. Prompts the user for the rank, name, and color of the new
    tier. If the rank is not an integer or if a tier with the input rank already
    exists, an error message is printed. Otherwise, adds the tier to the table
    tier and prints the tier_id.
    '''
    global conn
    rank = input('Enter the rank of the new tier. The rank must not be the same\
 as any existing tier and should be an integer: ')
    try:
        rank = int(rank)
    except ValueError:
        print_err(f'Failed to add tier: rank input {rank} was not a number')
        return
    name = input('Enter the name of the new tier: ')
    color = input('Enter the color of the new tier: ')

    sql = 'CALL sp_insert_tier(%d, \'%s\', \'%s\');' % (rank, name, color)
    try:
        cursor = conn.cursor()
        cursor.execute(sql)
        conn.commit()
        print_success('Tier added!')
    except mysql.connector.Error as err:
        if err.errno == errorcode.ER_DUP_ENTRY:
            print_err(f'Failed to add tier: Tier of the rank {rank} already exists')
        elif DEBUG:
            print(err)
        else:
            sys.stderr('An error occurred when adding the tier.')
        return
    try:
        cursor = conn.cursor()
        cursor.execute('SELECT LAST_INSERT_ID();')
        row = cursor.fetchone()
        print(f'ID of new tier: {row[0]}')
    except mysql.connector.Error as err:
        if DEBUG:
            print(err)
        else:
            sys.stderr('An error occurred when adding the tier.')

# ----------------------------------------------------------------------
# Functions for Logging Users In
# ----------------------------------------------------------------------
# Note: There's a distinction between database users (admin and client)
# and application users (e.g. members registered to a store). You can
# choose how to implement these depending on whether you have app.py or
# app-client.py vs. app-admin.py (in which case you don't need to
# support any prompt functionality to conditionally login to the sql database)
def login():
    '''
    Prompts the user to enter their username. If the user exists, prompts
    for a password. If the password is correct, logs the user in. Otherwise,
    if the password is wrong, returns to the startup menu.

    If the user does not exist, asks if the user wants to create a new user.
    If no, returns to the startup menu. If yes, prompts the user
    for a password and creates a new user with that username and password
    and logs into that user account.

    Once logged in, displays either the client or admin option menu depending
    on if the user is an admin or not.
    '''
    global conn
    username = input('Enter a username: ')
    # sql = 'SELECT username FROM user_info WHERE username LIKE \'%s\'' % (
    #                                                                 username,)
    # try:
    #     cursor = conn.cursor()
    #     cursor.execute(sql)
    #     result = cursor.fetchone()
    # except mysql.connector.Error as err:
    #     if DEBUG:
    #         sys.stderr(err)
    #         sys.exit(1)
    #     else:
    #         sys.stderr('An error occurred when searching for this username.')
    #         return

    # if result:
    if entry_exists('user_info', 'username', username):
        password = input('Enter your password: ')
        sql = 'SELECT authenticate(\'%s\', \'%s\')' % (username, password)
        try:
            cursor = conn.cursor()
            cursor.execute(sql)
            result = cursor.fetchone()
        except mysql.connector.Error as err:
            if DEBUG:
                sys.stderr(err)
                sys.exit(1)
            else:
                sys.stderr('An error occurred when authenticating this user.')
                return
        if result[0] == 1:
            print_success('Successfully logged in! Welcome back ' + username
                            + '!')
        else:
            print_err('Wrong password. Returning to startup menu...')
            return
    else:
        print_warning(f'No user with username \'{username}\'')
        ans = input('Would you like to create a new user? ')
        if ans and ans != "" and ans[0].lower() == 'y':
            password = input('Enter a password: ')
            # all new users created this way are client users
            sql = 'CALL sp_add_user(\'%s\', \'%s\');' % (username, password)
            try:
                cursor = conn.cursor()
                cursor.execute(sql)
                conn.commit()
                print_success(f'User \'{username}\' created!')
            except mysql.connector.Error as err:
                if DEBUG:
                  print(err)
                else:
                    sys.stderr('An error occurred when creating this user.')
                    return
        else:
            print('Returning to startup menu...')
            return

    if is_admin(username):
        conn.close()
        conn = get_conn(admin=True)
        show_admin_options(username)
    else:
        show_client_options(username)

def change_password(username):
    '''
    Prompts the user for a new password. Changes their password to the input
    password.
    '''
    global conn
    password = input('Enter new password: ')
    sql = 'CALL sp_change_password(\'%s\', \'%s\');' % (username, password)
    try:
        cursor = conn.cursor()
        cursor.execute(sql)
        conn.commit()
        print_success('Password changed!')
    except mysql.connector.Error as err:
        if DEBUG:
            print(err)
        else:
            sys.stderr('An error occurred when changing the password.')
            return

def is_admin(username):
    '''
    Checks if the given user is an admin. Returns true if user is admin, false
    otherwise. Prints an error message and returns None if the user is not
    found.
    '''
    global conn
    try:
        cursor = conn.cursor()
        cursor.execute('SELECT is_admin FROM user_info WHERE username=\'%s\'' % (username,))
        result = cursor.fetchone()
        if not result:
            print_err('username not found')
        else:
            return result[0] == 1
    except mysql.connector.Error as err:
        if DEBUG:
            sys.stderr(err)
            sys.exit(1)
        else:
            sys.stderr('An error occurred when searching for this username.')
            return

# ----------------------------------------------------------------------
# Command-Line Functionality
# ----------------------------------------------------------------------
def print_universal_options():
    '''
    Prints the options that are available for all users, both logged in
    and not logged in.
    '''
    print('  (h) - print the option menu again')
    print('  (g) - show the list of Nintendo games you can tier (displays at most 30 games)')
    print('  (s) - show rank statistics for a game')
    print('  (t) - show the different tiers')
    print('  (u) - show the list of tierlists you can view')
    print('  (v) - view a tierlist')

def print_logged_in_options():
    '''
    Prints the options that are available for logged in users, both admins
    and clients.
    '''
    print('  (p) - change your password')
    print('  (c) - create a new tierlist')
    print('  (d) - delete a tierlist')
    print("  (e) - edit a tierlist")

def print_startup_menu_options():
    '''
    Prints the options for the startup menu
    '''
    print_universal_options() # g, t, u, v, s
    print('  (l) - login or create an account')
    print('  (q) - quit')

def show_startup_options():
    """
    Displays options users can choose in the application startup, such as
    viewing games, tierlists, etc. or logging in.
    """
    print()
    print_bold('Welcome to Tiers of the Kingdom!')
    print('What would you like to do? ')
    print_startup_menu_options()
    while True:
        print()
        ans = input('Enter an option: ')
        if not ans or ans == "":
            continue
        ans = ans[0].lower()
        if ans == 'q':
            quit_ui()
        elif ans == 'h':
            print()
            print_startup_menu_options()
        elif ans == 'g':
            show_games()
        elif ans == 't':
            show_tiers()
        elif ans == 'u':
            show_tierlists()
        elif ans == 'v':
            view_tierlist()
        elif ans == 's':
            view_stats()
        elif ans == 'l':
            login()
        else:
            print('Unknown option.')

def print_client_menu_options():
    '''
    Prints the client menu options.
    '''
    print()
    print_bold('Main menu')
    print('What would you like to do? ')
    print_universal_options() # g, t, u, v
    print_logged_in_options() # p, c, d, e
    print('  (q) - quit')

def show_client_options(username):
    """
    Displays options clients can choose in the application, such as
    viewing games, tierlists, etc. and creating/editing/deleting tierlists.
    """
    print_client_menu_options()
    while True:
        print()
        ans = input('Enter an option: ')
        if not ans or ans == "":
            continue
        ans = ans[0].lower()
        if ans == 'q':
            quit_ui()
        elif ans == 'h':
            print_client_menu_options()
        elif ans == 'g':
            show_games()
        elif ans == 't':
            show_tiers()
        elif ans == 'u':
            show_tierlists()
        elif ans == 'v':
            view_tierlist()
        elif ans == 's':
            view_stats()
        elif ans == 'p':
            change_password(username)
        elif ans == 'c':
            create_tierlist(username)
        elif ans == 'd':
            delete_tierlist(username)
        elif ans == 'e':
            choose_tierlist_for_edit(username, False)
        else:
            print('Unknown option.')

def print_admin_menu_options():
    '''
    Prints the options for the admin menu.
    '''
    print()
    print_bold('Main menu')
    print('What would you like to do? ')
    print_universal_options() # g, t, u, v
    print_logged_in_options() # p, c, d, e
    print('  (a) - add a video game to the database')
    print('  (m) - update the sales of an existing video game')
    print('  (n) - add a new tier')
    print('  (q) - quit')

# You may choose to support admin vs. client features in the same program, or
# separate the two as different client and admin Python programs using the same
# database.
def show_admin_options(username):
    """
    Displays options admins can choose, such as adding new tiers/games,
    updating the sales for a game, as well as view tierlists, games, etc. and
    create/edit/delete tierlists.
    """
    print_admin_menu_options()
    while True:
        print()
        ans = input('Enter an option: ')
        if not ans or ans == "":
            continue
        ans = ans[0].lower()
        if ans == 'q':
            quit_ui()
        elif ans == 'h':
            print_admin_menu_options()
        elif ans == 'g':
            show_games()
        elif ans == 't':
            show_tiers()
        elif ans == 'u':
            show_tierlists()
        elif ans == 'v':
            view_tierlist()
        elif ans == 's':
            view_stats()
        elif ans == 'p':
            change_password(username)
        elif ans == 'c':
            create_tierlist(username)
        elif ans == 'd':
            delete_tierlist(username)
        elif ans == 'e':
            choose_tierlist_for_edit(username, True)
        elif ans == 'a':
            add_game()
        elif ans == 'm':
            update_game_sales()
        elif ans == 'n':
            add_tier()
        else:
            print('Unknown option.')

def edit_tierlist_options(username, name, is_admin):
    '''
    Prints the options that are available while editing a tierlist, such as
    adding/moving a game to a tier and deleting a game from the tierlist.
    '''
    print_bold(f'Edit Tierlist \'{name}\' Menu')
    print('What would you like to do? ')
    print("  (a) - add or move a game to a tier")
    print("  (d) - delete a game from the tierlist")
    print('  (q) - return to main menu')
    while True:
        print()
        ans = input(f'Enter an option to edit tierlist \'{name}\': ')
        if not ans or ans == "":
            continue
        ans = ans[0].lower()
        if ans == 'q':
            print('Returning to main menu...')
            if is_admin:
                print_admin_menu_options()
            else:
                print_client_menu_options()
            return
        elif ans == 'a':
            add_update_game_tier(username, name)
        elif ans == 'd':
            delete_game_tier(username, name)
        else:
            print('Unknown option.')

def quit_ui():
    """
    Quits the program, printing a good bye message to the user.
    """
    print("""The Legend of Zelda: Tears of the Kingdom releases May 12, 2023. \
An epic adventure across the land and skies of Hyrule awaits in The \
Legend of Zelda™: Tears of the Kingdom for Nintendo Switch™. The \
adventure is yours to create in a world fueled by your imagination.

In this sequel to The Legend of Zelda: Breath of the Wild, you’ll \
decide your own path through the sprawling landscapes of Hyrule and \
the mysterious islands floating in the vast skies above. Can you \
harness the power of Link’s new abilities to fight back against the \
malevolent forces that threaten the kingdom?""")
    print()
    print('Goodbye!')
    exit()

def main():
    """
    Main function for starting things up.
    """
    show_startup_options()

if __name__ == '__main__':
    # This conn is a global object that other functions can access.
    # You'll need to use cursor = conn.cursor() each time you are
    # about to execute a query with cursor.execute(<sqlquery>)
    conn = get_conn()
    print_success('Successfully connected.')
    main()
