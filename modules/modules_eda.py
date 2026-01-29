#########################################
##        Module: modules_eda.py       ##
#########################################

# Import necessary libraries #
##############################

import pandas as pd


# ----------------------------------------------------#

# Function to analyze distinct and missing values in a DataFrame #
##################################################################


def eda(df, variables, categorical = False, order_asc=False):
    
    """
    Build a DataFrame showing distinct values (if categorical=True), missing values count 
    and percentage for given variables for given DataFrame and subset of variables.

    Parameters:
        df (pd.DataFrame): The DataFrame to analyze.
        variables (list): List of variables to check for missing values.
        categorical (bool): If True, include distinct values count.
        order_asc (bool): If True, sort the result in ascending order of missing count.
    """

    eda_df = pd.DataFrame({
        'Variable': variables,
        'Missing_Count': df[variables].isna().sum().values,
        'Missing_Percentage': (df[variables].isna().sum() / len(df) *100).round(2).values
    })

 
    if categorical:
        eda_df['Distinct_Values_Count'] = df[variables].nunique().values
        return eda_df.sort_values(by=['Missing_Count', 'Distinct_Values_Count'], ascending=order_asc)

    else:
        return eda_df.sort_values('Missing_Count', ascending=order_asc)


# ----------------------------------------------------#